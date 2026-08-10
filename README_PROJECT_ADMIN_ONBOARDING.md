# Running a Field-Slip Event: Project Admin Onboarding

How to set up a Mushroom Observer project for a foray or fair that uses
printed field slips, and how to get yourself (or another organizer)
working as an admin — including the traps that have actually bitten
people.

## Setting up the project

1. **Field slip prefix.** Set the project's `field_slip_prefix` to the
   prefix printed on the slips (e.g. `2026-SMHF` for codes like
   `2026-SMHF-0207`). This is the link between a scanned or
   photographed code and the project: prefixes are unique, one per
   project, so an event printing two families of slips (the 2026 CMS
   fair had both `2026-CMS` and `2026-SMHF`) needs one project per
   prefix.
2. **Slip template.** The machine-reading pipeline needs to know which
   printed layout the slips use. Layouts are registered in
   `FieldSlip::Template` (`app/classes/field_slip/template.rb`) and
   selected by prefix. MO's own slips need nothing; a new event using
   DBG-style voucher slips needs its prefix added to
   `PROJECT_TEMPLATES` there — currently a small code change (issue
   #5027 tracks making this self-serve).
3. **Open membership.** Using a slip for an *open* project enrolls the
   collector automatically — that is what a printed prefix means. If
   the project is closed (`open_membership` off), a non-member's slip
   comes out project-less as a "spare", which looks like the scan
   silently failing. For an event where strangers collect, open the
   membership (or pre-enroll every collector).
4. **Constraints (location and dates) — read this twice.** If the
   project has a location constraint, observations that violate it are
   *silently left out of the project* even when their slip attaches.
   Two consequences:
   - An observation with a bad or missing locality can fail the
     constraint and quietly not join. Prefer loose constraints (or
     none) during the event; clean up after with the event report
     (below).
   - **The onboarding trap:** the observation form defaults the
     locality from your *previous* observation. An admin arriving from
     another region gets their old locality prefilled, the new
     observation violates the constraint, and the slip workflow appears
     broken. Workaround until this is fixed properly: on your first
     observation at the event, explicitly set the locality (or clear
     the prefilled one) before pressing Create. After that first one,
     the default follows you.
5. **Aliases.** Walk numbers, site abbreviations, and collector
   initials live in the project's aliases (Project → Admin → Aliases),
   and the slip-reading prompt is built from them — every alias added
   improves every later read. To seed from another project (last
   year's event, a sibling project):

   ```
   bin/rails runner script/copy_project_aliases.rb FROM_ID TO_ID          # dry run
   bin/rails runner script/copy_project_aliases.rb FROM_ID TO_ID --apply
   ```
6. **Admins.** Slip *reading and review* is limited to the project's
   admins (plus site admins): each read costs an API call and writes
   to observations the reviewer may not own. Recorders who should
   review must be admins, not just members.

## The slip pipeline, briefly

- **Creating an observation whose photo shows a slip** attaches the
  slip (and files the observation into the project) automatically when
  the QR decodes.
- **Read Field Slip** (button on the slip image's page) machine-reads
  the slip in the background; the page shows progress, failures get a
  Try Again button. A successful read also attaches the slip when the
  QR decode had missed it.
- **The review form** shows what was read next to what the observation
  holds; nothing is applied without the reviewer ticking it. GPS
  applies only as a full latitude/longitude pair; locality text the
  project can't resolve is kept verbatim rather than dropped.

## After the event

Bad collector data is expected — the goal is to capture everything and
clean up afterwards, not to block anyone at the table.

- `bin/rails runner script/field_slip_event_report.rb PROJECT_ID` —
  the cleanup queue: GPS that contradicts the named location
  (hemisphere flips show up here), free-text localities, observations
  with no GPS, iNaturalist notes that never resolved to a link, and
  slips with no observation.
- `bin/rails runner script/attach_slips_from_extracts.rb` (dry-run by
  default) — attaches any slip-less observations whose machine-read
  found a code the QR decode missed.

## Pre-event checklist

- [ ] Project exists with the correct `field_slip_prefix`
- [ ] Slip layout registered for that prefix (non-MO slips only)
- [ ] `open_membership` on, or every collector pre-enrolled
- [ ] Location/date constraints loose enough not to eject real
      observations
- [ ] Aliases seeded (sites, walks, collector initials)
- [ ] Every reviewer is a project admin
- [ ] Each reviewer has made (or edited) one observation with the
      event's locality, so the form default doesn't fight them
