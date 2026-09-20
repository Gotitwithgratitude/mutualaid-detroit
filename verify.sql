-- ═══════════ CayLink — verification record ═══════════
-- Run after commit.sql. Safe to re-run.
--
-- "It arrived" and "it works" are different facts, and only the second one matters to the person
-- who asked for it. Until now the on-site check was written to the events log and then vanished
-- from view — the one piece of information a commander most wants to see at a glance was the
-- hardest to find. These columns put it on the resource itself: verified, by whom, when.
-- Attribution is the point. An anonymous "verified" is a rumour; "verified by DPD at 9:23 PM"
-- is something you can act on, and something the wrong person can be held to afterwards.

alter table resources add column if not exists verified_by   text;
alter table resources add column if not exists verified_at   timestamptz;
alter table resources add column if not exists verified_note text;

-- on-site check now records WHO confirmed it, not just that it happened
create or replace function confirm_arrival(
  in_id bigint, in_actor text, in_working boolean, in_note text default null
) returns text as $$
declare cur text;
begin
  if coalesce(trim(in_actor),'') = '' then return 'Who is confirming this?'; end if;
  select status into cur from resources where id=in_id for update;
  if cur <> 'arrived' then return 'Mark it arrived first.'; end if;

  if in_working then
    update resources
       set verified_by = in_actor, verified_at = now(), verified_note = in_note
     where id = in_id;
    insert into events(resource_id, from_status, to_status, actor, detail)
      values (in_id, cur, 'verified', in_actor, coalesce(in_note,'on site, operational'));
    return 'ok';
  else
    update resources
       set status='out_of_service',
           oos_reason = coalesce(in_note,'failed on-site check'),
           verified_by = in_actor, verified_at = now(), verified_note = in_note,
           held_by=null, held_for=null, destination=null, eta_minutes=null
     where id = in_id;
    insert into events(resource_id, from_status, to_status, actor, detail)
      values (in_id, cur, 'out_of_service', in_actor, coalesce(in_note,'failed on-site check'));
    return 'ok';
  end if;
end;
$$ language plpgsql;

-- Returning something to service requires saying what was wrong and what was done about it.
-- A resource that silently reappears as available teaches everyone to distrust the board; a
-- line of explanation is the difference between a registry and a rumour mill.
create or replace function return_to_service(
  in_id bigint, in_actor text, in_note text
) returns text as $$
declare cur text; was text;
begin
  if coalesce(trim(in_actor),'') = '' then return 'Who is returning this to service?'; end if;
  if coalesce(trim(in_note),'')  = '' then return 'What was wrong, and what was done?'; end if;
  select status, oos_reason into cur, was from resources where id=in_id for update;
  if cur <> 'out_of_service' then return 'That resource is not out of service.'; end if;

  update resources
     set status='available', oos_reason=null,
         verified_by = in_actor, verified_at = now(), verified_note = in_note,
         held_by=null, held_for=null, destination=null, eta_minutes=null
   where id = in_id;
  insert into events(resource_id, from_status, to_status, actor, detail)
    values (in_id, cur, 'available', in_actor,
            'returned to service — was: ' || coalesce(was,'unspecified') || ' — fix: ' || in_note);
  return 'ok';
end;
$$ language plpgsql;

-- releasing a resource clears its verification: the next agency verifies for itself
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
           dest_lat=null, dest_lng=null, eta_minutes=null,
           verified_by=null, verified_at=null, verified_note=null where id=in_id;
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
