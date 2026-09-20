-- ═══════════ CayLink — the commitment chain ═══════════
-- Run AFTER setup.sql. Safe to re-run.
--
-- The rules Kobi specified are enforced HERE, not in the interface, because a rule that lives
-- only in a button can be clicked around — and in an incident the registry lying is worse than
-- the registry being empty. Specifically:
--   * "available" is never something a person selects; it is what a resource IS when nothing
--     holds it. Releasing is a consequence of the chain finishing, not a choice.
--   * only the agency that committed a resource can advance it
--   * en route is impossible without a destination, because "where is it going" is the question
--     the next person will ask
--   * out of service is the one status anyone may set — a broken pump is broken for everybody

alter table resources add column if not exists held_by      text;
alter table resources add column if not exists held_for     text;
alter table resources add column if not exists destination  text;
alter table resources add column if not exists dest_lat     double precision;
alter table resources add column if not exists dest_lng     double precision;
alter table resources add column if not exists eta_minutes  integer;
alter table resources add column if not exists oos_reason   text;

-- widen the status set to the full chain
alter table resources drop constraint if exists resources_status_check;
alter table resources add constraint resources_status_check
  check (status in ('available','committed','en_route','arrived','out_of_service'));

-- every state change is written down. an after-action review asks "who, when, and what did they
-- say" — this table is the answer, and nothing can change status without leaving a line in it.
create table if not exists events (
  id          bigint generated always as identity primary key,
  resource_id bigint not null references resources(id) on delete cascade,
  from_status text,
  to_status   text not null,
  actor       text not null,
  detail      text,
  at          timestamptz not null default now()
);
create index if not exists events_resource_idx on events (resource_id, at desc);

-- ── COMMIT ────────────────────────────────────────────────────────────────────
-- Requires who is taking it, what incident, and where it is going. Refuses if the resource is
-- already held: "you do not need to commit twice, and a second agency files a request."
create or replace function commit_resource(
  in_id bigint, in_actor text, in_incident text,
  in_destination text, in_dest_lat double precision default null,
  in_dest_lng double precision default null, in_eta integer default null
) returns text as $$
declare cur text; holder text;
begin
  select status, held_by into cur, holder from resources where id = in_id for update;
  if cur is null then return 'No such resource.'; end if;
  if cur = 'out_of_service' then return 'That resource is out of service.'; end if;
  if cur <> 'available' then
    return 'Already committed to ' || coalesce(holder,'another agency') ||
           '. File a request against it instead.';
  end if;
  if coalesce(trim(in_actor),'') = '' then return 'Who is committing this?'; end if;
  if coalesce(trim(in_incident),'') = '' then return 'Which incident is this for?'; end if;
  if coalesce(trim(in_destination),'') = '' then return 'Where is it going?'; end if;

  update resources set status='committed', held_by=in_actor, held_for=in_incident,
         destination=in_destination, dest_lat=in_dest_lat, dest_lng=in_dest_lng,
         eta_minutes=in_eta
   where id = in_id;
  insert into events(resource_id, from_status, to_status, actor, detail)
    values (in_id, cur, 'committed', in_actor, in_incident || ' → ' || in_destination);
  return 'ok';
end;
$$ language plpgsql;

-- ── ADVANCE ───────────────────────────────────────────────────────────────────
-- committed → en_route → arrived → (released to available). Only the holder may advance.
create or replace function advance_resource(
  in_id bigint, in_actor text, in_to text, in_detail text default null
) returns text as $$
declare cur text; holder text; dest text;
begin
  select status, held_by, destination into cur, holder, dest from resources where id=in_id for update;
  if cur is null then return 'No such resource.'; end if;
  if holder is null or lower(trim(holder)) <> lower(trim(in_actor)) then
    return 'Only ' || coalesce(holder,'the holding agency') || ' can change this.';
  end if;
  if in_to = 'en_route' then
    if cur <> 'committed' then return 'Only a committed resource can go en route.'; end if;
    if coalesce(trim(dest),'') = '' then return 'No destination set — cannot mark en route.'; end if;
    update resources set status='en_route' where id=in_id;
  elsif in_to = 'arrived' then
    if cur <> 'en_route' then return 'Mark it en route first.'; end if;
    update resources set status='arrived' where id=in_id;
  elsif in_to = 'released' then
    if cur not in ('arrived','en_route','committed') then return 'Nothing to release.'; end if;
    update resources set status='available', held_by=null, held_for=null, destination=null,
           dest_lat=null, dest_lng=null, eta_minutes=null where id=in_id;
    insert into events(resource_id, from_status, to_status, actor, detail)
      values (in_id, cur, 'available', in_actor, coalesce(in_detail,'released'));
    return 'ok';
  else
    return 'Unknown step.';
  end if;
  insert into events(resource_id, from_status, to_status, actor, detail)
    values (in_id, cur, in_to, in_actor, in_detail);
  return 'ok';
end;
$$ language plpgsql;

-- ── ON-SITE CHECK ─────────────────────────────────────────────────────────────
-- The dispatch coordinator confirms it arrived AND that it works. A pump that showed up broken
-- is not a delivered resource, and the registry should say so rather than quietly counting it.
create or replace function confirm_arrival(
  in_id bigint, in_actor text, in_working boolean, in_note text default null
) returns text as $$
declare cur text;
begin
  select status into cur from resources where id=in_id for update;
  if cur <> 'arrived' then return 'Mark it arrived first.'; end if;
  if in_working then
    insert into events(resource_id, from_status, to_status, actor, detail)
      values (in_id, cur, 'checked_ok', in_actor, coalesce(in_note,'on site, operational'));
    return 'ok';
  else
    update resources set status='out_of_service', oos_reason=coalesce(in_note,'failed on-site check'),
           held_by=null, held_for=null, destination=null, eta_minutes=null where id=in_id;
    insert into events(resource_id, from_status, to_status, actor, detail)
      values (in_id, cur, 'out_of_service', in_actor, coalesce(in_note,'failed on-site check'));
    return 'ok';
  end if;
end;
$$ language plpgsql;

-- ── OUT OF SERVICE — anyone, any time, with a reason ──────────────────────────
create or replace function mark_out_of_service(
  in_id bigint, in_actor text, in_reason text
) returns text as $$
declare cur text;
begin
  if coalesce(trim(in_reason),'') = '' then return 'Give a reason.'; end if;
  select status into cur from resources where id=in_id for update;
  update resources set status='out_of_service', oos_reason=in_reason,
         held_by=null, held_for=null, destination=null, eta_minutes=null where id=in_id;
  insert into events(resource_id, from_status, to_status, actor, detail)
    values (in_id, cur, 'out_of_service', in_actor, in_reason);
  return 'ok';
end;
$$ language plpgsql;

alter table events enable row level security;
drop policy if exists events_read on events;
create policy events_read on events for select using (true);
drop policy if exists events_write on events;
create policy events_write on events for insert with check (true);

-- ── DEMO RESET ────────────────────────────────────────────────────────────────
-- "Start from a prepared state — no sign-ups on stage." Run this before demoing.
create or replace function reset_demo() returns void as $$
begin
  delete from events;
  delete from requests;
  update resources set status='available', held_by=null, held_for=null, destination=null,
         dest_lat=null, dest_lng=null, eta_minutes=null, oos_reason=null;
  update resources set status='committed', held_by='DFD Engine 17', held_for='Structure fire, Mack & Bewick',
         destination='Mack & Bewick' where name='Portable pump, 3in';
  update resources set status='out_of_service', oos_reason='Impeller repair, ETA 48h' where name='Trash pump, 6in';
  update resources set status='en_route', held_by='DTE storm staging', held_for='Feeder down, Livernois',
         destination='Livernois & Fenkell', eta_minutes=14 where name='Generator, 45kW';
end;
$$ language plpgsql;
