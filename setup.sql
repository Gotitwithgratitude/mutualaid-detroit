-- ═══════════ MutualAid Detroit — ONE-SHOT SETUP ═══════════
-- Paste this ENTIRE file into the Supabase SQL editor and press Run. Once.
-- It creates the table, the proximity function and the security policies, then loads
-- demonstration data — in that order, so the ordering mistake is impossible to make.
-- Safe to re-run: existing seed rows are cleared first rather than duplicated.

-- MutualAid Detroit — resource registry schema
-- Run this in the Supabase SQL editor.
--
-- Design notes:
--  * One table. During an incident the question is always the same shape — what is near me,
--    what kind is it, can I have it, who do I call — so the schema is flat on purpose.
--    Normalising agencies into their own table buys nothing here and costs a join on every
--    query written under pressure.
--  * Status is a small fixed set rather than free text. "Available" has to mean the same thing
--    to DFD and DPW or the whole registry is noise.
--  * updated_at matters as much as the resource itself: a generator marked available six hours
--    ago is not a fact, it's a guess. The UI surfaces the age so nobody treats stale as current.

create table if not exists resources (
  id            bigint generated always as identity primary key,
  agency        text not null,                 -- who owns it: "DFD Engine 30", "DPW Yard 3"
  kind          text not null,                 -- pump | generator | light | vehicle | shelter | crew
  name          text not null,                 -- human label: "Portable pump, 4in"
  lat           double precision not null,
  lng           double precision not null,
  status        text not null default 'available'
                check (status in ('available','committed','en_route','out_of_service')),
  capacity      text,                          -- free text: "60 beds", "45kW", "1500 gpm"
  contact       text,                          -- who to call for it
  notes         text,
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists resources_status_idx on resources (status);
create index if not exists resources_kind_idx   on resources (kind);

-- Keep updated_at honest — a stale row that looks fresh is worse than no row.
create or replace function touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists resources_touch on resources;
create trigger resources_touch before update on resources
  for each row execute function touch_updated_at();

-- Proximity search: everything within N metres of an incident, nearest first.
-- Plain haversine rather than PostGIS — no extension needed, and at city scale the difference
-- is metres. Exposed as an RPC so the n8n/MCP connector can call it as one named operation.
create or replace function resources_near(
  in_lat double precision,
  in_lng double precision,
  radius_m double precision default 5000,
  only_available boolean default true
)
returns table (
  id bigint, agency text, kind text, name text,
  lat double precision, lng double precision,
  status text, capacity text, contact text,
  distance_m double precision, minutes_since_update integer
) as $$
  select r.id, r.agency, r.kind, r.name, r.lat, r.lng, r.status, r.capacity, r.contact,
         6371000 * 2 * asin(sqrt(
           power(sin(radians(r.lat - in_lat) / 2), 2) +
           cos(radians(in_lat)) * cos(radians(r.lat)) *
           power(sin(radians(r.lng - in_lng) / 2), 2)
         )) as distance_m,
         (extract(epoch from (now() - r.updated_at)) / 60)::int as minutes_since_update
  from resources r
  where (not only_available or r.status = 'available')
    and 6371000 * 2 * asin(sqrt(
          power(sin(radians(r.lat - in_lat) / 2), 2) +
          cos(radians(in_lat)) * cos(radians(r.lat)) *
          power(sin(radians(r.lng - in_lng) / 2), 2)
        )) <= radius_m
  order by distance_m asc;
$$ language sql stable;

-- Row level security: readable by anyone, writable by anyone for the demo.
-- NOT how this ships to real agencies — a production deployment needs per-agency identity so
-- DPW cannot mark a DFD truck out of service. Stated plainly rather than left implied.
alter table resources enable row level security;

drop policy if exists resources_read on resources;
create policy resources_read on resources for select using (true);

drop policy if exists resources_write on resources;
create policy resources_write on resources for insert with check (true);

drop policy if exists resources_update on resources;
create policy resources_update on resources for update using (true);

-- ── demonstration data ──
-- Plausible, NOT real: real Detroit locations, invented resources. Labelled as demo data
-- in the app, and it must be described that way in any pitch.
delete from resources;

insert into resources (agency, kind, name, lat, lng, status, capacity, contact, notes) values
  -- Fire — suppression and special ops
  ('DFD Engine 30',        'pump',      'Portable pump, 4in',        42.3505, -83.0402, 'available',      '1500 gpm',  'DFD Dispatch',        'Trailer-mounted'),
  ('DFD Engine 17',        'pump',      'Portable pump, 3in',        42.3821, -83.0912, 'committed',      '750 gpm',   'DFD Dispatch',        'Assigned to active incident'),
  ('DFD Special Ops',      'vehicle',   'High-water rescue vehicle', 42.3390, -83.0510, 'available',      '8 pax',     'Special Ops desk',    'Flood response'),
  ('DFD Special Ops',      'crew',      'Swift water team',          42.3390, -83.0510, 'en_route',       '6 members', 'Special Ops desk',    ''),
  ('DFD Ladder 8',         'vehicle',   'Aerial ladder',             42.3652, -83.0721, 'available',      '100 ft',    'DFD Dispatch',        ''),

  -- Public works — the equipment nobody remembers to ask for
  ('DPW Yard 3',           'light',     'Light tower, towable',      42.3712, -83.0655, 'available',      '4x1000W',   'Yard supervisor',     'Diesel, 8hr runtime'),
  ('DPW Yard 3',           'generator', 'Generator, 25kW',           42.3712, -83.0655, 'available',      '25kW',      'Yard supervisor',     ''),
  ('DPW Yard 1',           'vehicle',   'Dump truck w/ plow',        42.3288, -83.0821, 'available',      '10 yd',     'Yard 1 dispatch',     'Debris clearance'),
  ('DPW Yard 1',           'pump',      'Trash pump, 6in',           42.3288, -83.0821, 'out_of_service', '2200 gpm',  'Yard 1 dispatch',     'Impeller repair, ETA 48h'),

  -- Utility staging
  ('DTE storm staging',    'generator', 'Generator, 45kW',           42.3430, -83.0600, 'en_route',       '45kW',      'Storm desk',          'Mobilizing from Warren'),
  ('DTE storm staging',    'crew',      'Line crew',                 42.3430, -83.0600, 'committed',      '4 members', 'Storm desk',          ''),

  -- Shelter and warming capacity — the resource most often missing from a resource list
  ('Butzel Family Center', 'shelter',   'Warming shelter',           42.3799, -83.0180, 'available',      '60 beds',   'Site lead',           'Generator backed'),
  ('Adams Butzel Complex', 'shelter',   'Warming shelter',           42.3661, -83.1682, 'available',      '85 beds',   'Site lead',           ''),
  ('Patton Rec Center',    'shelter',   'Cooling/warming center',    42.3298, -83.1613, 'committed',      '40 beds',   'Site lead',           'In use'),

  -- Medical
  ('DMC Receiving',        'crew',      'Mobile triage unit',        42.3538, -83.0570, 'available',      '2 bays',    'Charge nurse',        ''),
  ('Detroit EMS Station 4','vehicle',   'Ambulance, ALS',            42.3948, -83.0410, 'available',      '2 pax',     'EMS Dispatch',        ''),

  -- Transit — moving people is a resource, and it is rarely on anyone's list
  ('DDOT Shoemaker',       'vehicle',   'Transit bus (evac capable)',42.3771, -82.9980, 'available',      '40 pax',    'DDOT ops',            'Wheelchair accessible'),
  ('DDOT Gilbert',         'vehicle',   'Transit bus (evac capable)',42.3352, -83.1260, 'available',      '40 pax',    'DDOT ops',            '');

-- ═══════════ v2 — REQUESTS: the loop after the search ═══════════
-- A registry that only answers "who has one" stops exactly where the work starts. What Tony
-- Watts described — twice — was being NOTIFIED that a resource is needed. So a request is a
-- first-class row: who asked, for what, where, who owns it, and what they said back.
-- Both sides see the same record, and every state change is timestamped. In an after-action
-- review the question is always "when did we ask, and when did they answer" — this answers it.

create table if not exists requests (
  id            bigint generated always as identity primary key,
  resource_id   bigint references resources(id) on delete set null,
  requested_by  text not null,              -- requesting agency / incident commander
  incident      text,                       -- free text: "Structure fire, Jefferson & Chene"
  lat           double precision,
  lng           double precision,
  note          text,
  state         text not null default 'pending'
                check (state in ('pending','accepted','declined','released')),
  response_note text,
  eta_minutes   integer,
  created_at    timestamptz not null default now(),
  answered_at   timestamptz,
  closed_at     timestamptz
);

create index if not exists requests_state_idx    on requests (state);
create index if not exists requests_resource_idx on requests (resource_id);

-- Answering a request and changing the resource's status are ONE action, not two. Two would
-- drift: someone accepts and forgets to mark the pump committed, and the map lies. Doing both
-- inside a single function means the registry cannot disagree with itself.
create or replace function answer_request(
  in_id bigint,
  in_state text,
  in_note text default null,
  in_eta integer default null
) returns void as $$
begin
  update requests
     set state = in_state,
         response_note = coalesce(in_note, response_note),
         eta_minutes = coalesce(in_eta, eta_minutes),
         answered_at = now(),
         closed_at = case when in_state in ('declined','released') then now() else closed_at end
   where id = in_id;

  if in_state = 'accepted' then
    update resources set status = 'committed'
     where id = (select resource_id from requests where id = in_id);
  elsif in_state = 'released' then
    update resources set status = 'available'
     where id = (select resource_id from requests where id = in_id);
  end if;
end;
$$ language plpgsql;

alter table requests enable row level security;
drop policy if exists requests_read on requests;
create policy requests_read on requests for select using (true);
drop policy if exists requests_write on requests;
create policy requests_write on requests for insert with check (true);
drop policy if exists requests_update on requests;
create policy requests_update on requests for update using (true);
