# MutualAid Detroit

**When an emergency crosses agency lines, nobody can see what the other agencies have.**

Built for the TechTown Venture 313 Buildathon (Sept 17–22, 2026).
Challenge pillars: **Reliable Transportation** and **Infrastructure & Sustainability**.

---

## The problem

From the technical briefing with Tony Watts, Special Projects Director, Detroit Fire
Department (28 years in DFD):

- Agencies work in silos. Five agencies can sit in one building and still not share a view of
  their resources.
- During a large incident — a flood, a storm, a multi-alarm fire — communication fails first.
- There is no common system for answering the simplest operational question in a crisis:
  *who has what, and where is it right now?*
- Mutual aid happens by phone calls and personal relationships. If you don't know the right
  person at the right agency, the resource might as well not exist.

He said it twice, unprompted: what's missing is something that **tells you a needed resource
is available**.

This is not a hardware problem or a funding problem. It's a visibility problem.

## What this is

A shared, lightweight resource registry for incident response, plus a connector that lets an
AI assistant answer resource questions in plain language.

- Agencies post what they have: vehicles, generators, pumps, crews, shelter capacity.
- Everything is placed on a map, with status and a point of contact.
- An MCP connector exposes it, so dispatch can ask *"what pumps are available within two miles
  of Jefferson and Chene, and who do I call?"* and get an answer instead of a phone tree.

## Why a connector, not just an app

An app is one more system to check during the worst hour of someone's week. Emergency
personnel already have several. Exposing the registry over the Model Context Protocol means
the data can be reached from whatever assistant an agency already uses — the information goes
to where the responder already is, rather than asking them to come to it.

## Scope for this build

In scope for the Buildathon:

- [ ] Resource registry (agency, resource type, location, status, contact)
- [ ] Add and update resources
- [ ] Map view of what's available
- [ ] Proximity search — what's near this incident
- [ ] MCP connector over the registry, built with n8n
- [ ] Seed data representing realistic Detroit agency resources

Deliberately **out** of scope: authentication, real agency system integrations, mobile apps,
dispatch workflow. Those matter for a real deployment and cannot be done honestly in five days.

## Status

Started Thursday, September 17, 2026 — Day 1 of the Buildathon. Built solo.

## Stack

Static web front end · Supabase (Postgres) · n8n + MCP connector · deployed on Cloudflare

## License

© 2026 Got It With Gratitude LLC. All rights reserved.
