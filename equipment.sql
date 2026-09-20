-- ═══════════ CayLink — real departmental equipment ═══════════
-- Run after verify.sql. Safe to re-run: it clears and reloads demonstration rows only.
--
-- Why this exists: asking for "light" was returning a cooling centre and a bus. That is a
-- vocabulary problem, not a search problem — six resource kinds cannot describe what a fire
-- department, a public works yard and a utility actually park in their bays, so everything
-- collapsed into the nearest wrong bucket. These kinds follow how the equipment is talked about
-- on a fireground, and the seed covers what each department genuinely holds.
--
-- STILL DEMONSTRATION DATA. Real Detroit locations, plausible equipment, no agency has confirmed
-- any of it. That has to be said out loud in the pitch.

alter table resources drop constraint if exists resources_kind_check;
alter table resources add constraint resources_kind_check check (kind in (
  'pump','generator','light','vehicle','shelter','crew',
  'apparatus','hazmat','medical','heavy','barrier','comms','air','water','fuel','k9','drone'
));

delete from resources;

insert into resources (agency, kind, name, lat, lng, status, capacity, contact, notes) values
  -- ── DFD — suppression, special ops, EMS ──
  ('DFD Engine 30',  'apparatus','Engine company, 1500 gpm',    42.3505,-83.0402,'available','1500 gpm','DFD Dispatch','Pump and 500 gal tank'),
  ('DFD Ladder 8',   'apparatus','Aerial ladder, 100 ft',       42.3652,-83.0721,'available','100 ft','DFD Dispatch',''),
  ('DFD Engine 17',  'pump',     'Portable pump, 3in',          42.3821,-83.0912,'available','750 gpm','DFD Dispatch','Trailer mounted'),
  ('DFD Engine 30',  'pump',     'Portable pump, 4in',          42.3505,-83.0402,'available','1500 gpm','DFD Dispatch','Trailer mounted'),
  ('DFD Special Ops','vehicle',  'High-water rescue vehicle',   42.3390,-83.0510,'available','8 pax','Special Ops desk','Flood response'),
  ('DFD Special Ops','crew',     'Swift water rescue team',     42.3390,-83.0510,'available','6 members','Special Ops desk',''),
  ('DFD Special Ops','hazmat',   'Hazmat decon trailer',        42.3390,-83.0510,'available','3-lane decon','Special Ops desk',''),
  ('DFD Special Ops','air',      'SCBA air cascade trailer',    42.3390,-83.0510,'available','6 cylinders','Special Ops desk','Refills on scene'),
  ('DFD Squad 4',    'crew',     'Technical rescue team',       42.3944,-83.0725,'available','8 members','DFD Dispatch','Confined space, rope'),
  ('DFD Training',   'light',    'Scene light tower, towable',  42.3610,-83.1074,'available','4x1000W','Logistics','Diesel, 8h runtime'),

  -- ── Detroit EMS ──
  ('Detroit EMS Station 4','medical','Ambulance, ALS',          42.3948,-83.0410,'available','2 patients','EMS Dispatch',''),
  ('Detroit EMS Station 17','medical','Ambulance, BLS',         42.3316,-83.1509,'available','2 patients','EMS Dispatch',''),
  ('Detroit EMS',    'medical',  'Mass casualty trailer',       42.3538,-83.0570,'available','50 patients','EMS Supervisor','Triage tags, litters'),
  ('DMC Receiving',  'crew',     'Mobile triage unit',          42.3538,-83.0570,'available','2 bays','Charge nurse',''),

  -- ── DPW — the equipment nobody remembers to ask for ──
  ('DPW Yard 1',     'heavy',    'Front-end loader',            42.3288,-83.0821,'available','2.5 yd bucket','Yard 1 dispatch','Debris clearance'),
  ('DPW Yard 1',     'vehicle',  'Dump truck w/ plow',          42.3288,-83.0821,'available','10 yd','Yard 1 dispatch',''),
  ('DPW Yard 1',     'pump',     'Trash pump, 6in',             42.3288,-83.0821,'out_of_service','2200 gpm','Yard 1 dispatch','Impeller repair'),
  ('DPW Yard 3',     'light',    'Light tower, towable',        42.3712,-83.0655,'available','4x1000W','Yard supervisor',''),
  ('DPW Yard 3',     'generator','Generator, 25kW towable',     42.3712,-83.0655,'available','25kW','Yard supervisor',''),
  ('DPW Yard 3',     'barrier',  'Type III barricades',         42.3712,-83.0655,'available','40 units','Yard supervisor','Road closure'),
  ('DPW Yard 3',     'barrier',  'Message board, portable',     42.3712,-83.0655,'available','2 units','Yard supervisor','Solar'),
  ('DPW Yard 5',     'heavy',    'Backhoe',                     42.4019,-83.1305,'available','','Yard 5 dispatch',''),
  ('DPW Yard 5',     'vehicle',  'Water tanker',                42.4019,-83.1305,'available','2000 gal','Yard 5 dispatch',''),

  -- ── DWSD — water and sewer ──
  ('DWSD Central',   'pump',     'Bypass pump, 8in',            42.3455,-83.0801,'available','4000 gpm','DWSD ops','Sewer bypass'),
  ('DWSD Central',   'water',    'Vactor truck',                42.3455,-83.0801,'available','12 yd debris','DWSD ops','Catch basin clearing'),
  ('DWSD Central',   'crew',     'Sewer response crew',         42.3455,-83.0801,'available','4 members','DWSD ops',''),

  -- ── DTE — power ──
  ('DTE storm staging','generator','Generator, 45kW towable',   42.3430,-83.0600,'available','45kW','Storm desk',''),
  ('DTE storm staging','generator','Generator, 100kW trailer',  42.3430,-83.0600,'available','100kW','Storm desk','Facility backup'),
  ('DTE storm staging','crew',   'Line crew',                   42.3430,-83.0600,'available','4 members','Storm desk',''),
  ('DTE storm staging','fuel',   'Fuel tender',                 42.3430,-83.0600,'available','500 gal diesel','Storm desk','Refuels generators'),

  -- ── DDOT — moving people is a resource ──
  ('DDOT Shoemaker', 'vehicle',  'Transit bus, evacuation',     42.3771,-82.9980,'available','40 pax','DDOT ops','Wheelchair accessible'),
  ('DDOT Gilbert',   'vehicle',  'Transit bus, evacuation',     42.3352,-83.1260,'available','40 pax','DDOT ops',''),
  ('DDOT Gilbert',   'vehicle',  'Paratransit van',             42.3352,-83.1260,'available','8 pax + 2 chairs','DDOT ops','Medical transport'),

  -- ── Shelter ──
  ('Butzel Family Center','shelter','Warming shelter',          42.3799,-83.0180,'available','60 beds','Site lead','Generator backed'),
  ('Adams Butzel Complex','shelter','Warming shelter',          42.3661,-83.1682,'available','85 beds','Site lead',''),
  ('Patton Rec Center','shelter','Cooling centre',              42.3298,-83.1613,'available','40 beds','Site lead',''),
  ('Kemeny Rec Center','shelter','Cooling centre',              42.2963,-83.1122,'available','35 beds','Site lead',''),

  -- ── DPD ──
  ('DPD 3rd Precinct','comms',   'Mobile command post',         42.3419,-83.0621,'available','8 positions','DPD dispatch','Radio patch, satellite'),
  ('DPD Special Ops','drone',    'UAS team',                    42.3419,-83.0621,'available','2 aircraft','DPD dispatch','Thermal camera'),
  ('DPD K9',         'k9',       'Search K9 unit',              42.3419,-83.0621,'available','2 teams','DPD dispatch',''),
  ('DPD Traffic',    'barrier',  'Traffic control unit',        42.3419,-83.0621,'available','6 officers','DPD dispatch','Intersection control'),

  -- ── Homeland Security & Emergency Management ──
  ('Detroit HSEM',   'comms',    'Interoperable radio cache',   42.3297,-83.0458,'available','50 handhelds','EOC','Cross-agency patch'),
  ('Detroit HSEM',   'shelter',  'Shelter support trailer',     42.3297,-83.0458,'available','100 cots','EOC',''),
  ('Detroit HSEM',   'generator','Generator, 60kW',             42.3297,-83.0458,'available','60kW','EOC','EOC backup');
