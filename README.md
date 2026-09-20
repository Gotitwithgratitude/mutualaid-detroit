# CayLink

**When an emergency crosses agency lines, nobody can see what the other agencies have.**

A shared resource registry for Detroit emergency response, and a commitment chain that records
who took what, where it went, and whether it worked when it got there.

Built solo for the TechTown **Venture 313 Buildathon**, 17–22 September 2026.
Pillars: **Reliable Transportation** · **Infrastructure & Sustainability**

**Live:** https://gotitwithgratitude.github.io/mutualaid-detroit/

---

## The problem

From the technical briefing with **Tony Watts**, Special Projects Director, Detroit Fire
Department, 28 years in DFD:

- Agencies work in silos. Five agencies can sit in one building and still not share a view of
  their resources.
- During a large incident — a flood, a storm, a multi-alarm fire — communication fails first.
- There is no common system for answering the simplest operational question in a crisis:
  *who has what, and where is it right now?*
- Mutual aid runs on phone calls and personal relationships. If you don't know the right person
  at the right agency, the resource might as well not exist.

He said one thing twice, unprompted: what's missing is something that **tells you a needed
resource is available**. This is not a hardware problem or a funding problem. It is a visibility
problem.

## The name

**CAY-LINK** — C, A, Y for Coleman A. Young, Detroit's first Black mayor. He disbanded the
STRESS police unit and pushed the integration of a department where Black officers were under
10% of the force in 1974 and over 50% by 1993. A man who spent his career connecting a city that
wasn't connected.

---

## What it does

**A shared registry.** Every agency posts what it holds — pumps, generators, light towers,
apparatus, ambulances, buses, shelter capacity, crews, radio caches — on one map, with status,
capacity, contact and the age of that information.

**Plain-language search.** *"What can put water on a fire near Chene?"* The model turns the
question into a structured query; **Postgres answers it**; the model writes one sentence about
the rows that came back. It never invents a resource. Every answer carries its provenance.

**The commitment chain.** The part that makes it a system rather than a directory:

```
available → COMMIT        requires who / what incident / where it is going
          → EN ROUTE      impossible without a destination
          → ARRIVED
          → CHECKED       works, or doesn't — a broken pump is not a delivered resource
          → RELEASED      back to available
```

**Live tracking.** A four-stage progress bar, a dashed line drawn on the map from the equipment
to its destination, and an ETA that counts down and then reports itself overdue rather than
counting into the negative.

## Rules the interface cannot break

Every one of these is enforced in Postgres, not in a button, because a rule that lives in a
button can be clicked around — and in an incident a registry that lies is worse than one that
is empty.

- **"Available" is never selectable.** It is what a resource *is* when nothing holds it.
- **Committing requires who, what incident, and where.** The database refuses without all three.
- **Nothing is committed twice.** A second agency is told *"Already committed to DFD Engine 17.
  File a request against it instead."*
- **Only the holder advances it.** Anyone else files a request — the exception path, not the
  main one.
- **En route is impossible without a destination.** That is why destination is required at commit.
- **Out of service** can be set by anyone, at any time, with a reason. A broken pump is broken
  for everybody.
- **Returning to service requires saying what was wrong and what was done.** A resource that
  silently reappears teaches everyone to distrust the board.
- **Verification is attributed and expires on release.** "Verified by DPD at 9:23 PM" is
  actionable; an anonymous "verified" is a rumour. The next agency verifies for itself.
- **Every transition is written to an `events` table** — who, when, from what, to what. After an
  incident the question is always *when did we ask, and when did they answer*.

## Demonstration data

The 44 resources are **plausible, not real**: real Detroit locations, invented equipment. No
agency has confirmed any of it. The app says so in the header and it is said out loud in the
pitch.

**Demo mode** stands in for the other agency during a presentation, advancing a commitment one
stage every twelve seconds. It is off on every page load, requires a deliberate tap, and is
labelled on the button, on every card it touches, and in every message it produces.

---

## Stack

| Layer | Choice |
|---|---|
| Front end | One self-contained HTML file · MapLibre GL · OpenStreetMap tiles |
| Database | Supabase Postgres, row level security on every table |
| Proximity | `resources_near()` — haversine in SQL, no PostGIS needed |
| Model | `gpt-4o-mini`, temperature 0, behind a Supabase Edge Function |
| Geocoding | Nominatim, with coordinate entry and long-press as fallbacks |
| Hosting | GitHub Pages |

The OpenAI key is a **server secret**, never in this repository and never in the page source.
Rate limiting lives in the edge function, where a browser could not enforce it honestly.

## Setting it up

Run these in the Supabase SQL editor, in order:

1. `setup.sql` — resources table, proximity function, RLS, requests
2. `commit.sql` — the commitment chain and the events log
3. `verify.sql` — verification record and return-to-service
4. `equipment.sql` — 17 resource kinds and 44 seeded resources

Then deploy `ask-index.ts` as an Edge Function named `ask`, and set the `OPENAI_API_KEY` secret.

`reset_demo()` returns the board to a realistic mixed state before a presentation.

## Deliberately not built

Named rather than hidden — each one is a real requirement for deployment, and five days was not
enough to do any of them honestly:

- **Per-agency authentication.** Today the app trusts the agency name you type. Real deployment
  needs identity, so DPW cannot mark a DFD truck out of service.
- **Live GPS position.** The map shows the *planned* trip and a stated ETA. Actual position
  needs a device in the vehicle reporting in.
- **Integration with existing CAD systems.** The registry is standalone.
- **Asset readiness and preventative maintenance** — how old the machine is, when it was last
  serviced. A different product with a different buyer.

## Roadmap

1. Agency identity and per-agency permissions
2. Telemetry from vehicles for real position and automatic arrival
3. Priority ranking when two incidents want the same resource
4. County-level deployment — Michigan has 83 emergency management offices, each with a
   mutual-aid mandate

---

© 2026 Got It With Gratitude LLC. Map data © OpenStreetMap contributors.
