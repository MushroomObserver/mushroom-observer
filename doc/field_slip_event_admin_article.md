# Running a Field-Slip Event: A Guide for Project Admins

Draft for an MO Article. Audience: project admins with no knowledge of
the code base. Once published on the site, the article is the living
copy and this draft can be deleted; developer-facing details live in
`README_FIELD_SLIP_EVENTS.md`.

---

Field slips let a foray or fair capture specimens fast: collectors drop
a printed slip in the bag with each collection, photograph it, and
Mushroom Observer connects the photo, the observation, the specimen,
and your project automatically. This guide covers setting up a project
for a slip event and the lessons learned from running them. If you get
stuck at any point, email webmaster@mushroomobserver.org — the
development team can help with anything this guide can't.

## Choosing your field slips

There are currently two styles of printed slip Mushroom Observer can read:

- **MO-style slips (recommended).** Mushroom Observer's own printed
  slips, with a QR code and boxes for collector, date, location,
  notes, and identification. Any project with a field slip prefix can
  create and print these immediately, no help needed: go to your
  project's **Admin → Field Slips** tab.
- **DBG-style voucher slips.** A layout associated with the Denver
  Botanic Gardens herbarium program, used by events collecting into
  that herbarium. If you are running a DBG-style foray you will
  already be in contact with a DBG curator, who can help you create
  appropriate slips. Enabling Mushroom Observer's automatic reading
  for a new DBG-style event currently requires a small change by the
  development team — email webmaster@mushroomobserver.org well before
  the event.

Contact the development team if you need to use another type of
field slip.  This requires a few more changes and requires a bit
more lead time, but is not difficult.

## Setting up the project

1. **Field slip prefix.** Give your project a field slip prefix
   matching what is printed on the slips — for example the prefix
   `2026-SMHF` for slips numbered `2026-SMHF-0207`. The prefix is what
   connects a scanned slip to your project. Prefixes are one per
   project, so an event using more than one family of slips needs one
   project for each prefix.
2. **Open membership.** Using a slip automatically enrolls the
   collector in the project — but only when the project's membership
   is open. If membership is closed, a stranger's slip quietly ends up
   attached to no project at all, which may look like the system failing.
   For an event where the public collects, open the membership (or
   pre-enroll every collector).
3. **Location and date constraints — read this twice.** If the project
   constrains locations or dates, an observation that violates them
   stays out of the project (along with its slip) until the data is
   fixed. Keep constraints loose during the event — an honest date
   range and a generous location — and clean up data afterwards rather
   than blocking anyone at the table.
4. **Aliases.** Walk numbers, collecting-site abbreviations, and
   collector initials go in **Admin → Aliases** on your project. The
   automatic slip reading uses them to turn what collectors scribble
   ("EB2", "Walk 3") into real locations and members — every alias you
   add improves every later slip. To copy the alias list from a
   previous year's project in bulk, email
   webmaster@mushroomobserver.org.
5. **Make your reviewers admins.** Reading and reviewing slips is
   limited to the project's admins. Anyone who will review scans at
   the event needs to be a project admin, not just a member.

## How the slip workflow looks at the table

- **Create an observation whose photo shows the slip**: when the QR
  code is readable, the slip attaches and the observation files into
  your project automatically.
- **When the QR couldn't be read** (glare, angle, a thumb), the site
  says so and goes to a page where you choose which photo shows the slip
  and press **Read Field Slip**. The reading runs in the background
  and usually takes about fifteen seconds.
- **The review page** shows everything the reading found next to what
  the observation currently says. Nothing is applied unless the
  reviewer ticks it. This is where the slip's date, locality, GPS, and
  identification land on the observation.

## After the event

Messy collector data is expected — the goal is to capture everything
during the event and tidy afterwards. The development team can
generate a cleanup report for your project listing observations whose
GPS and locality disagree, localities that never matched a real place,
observations with no GPS, and slips that never got an observation —
email webmaster@mushroomobserver.org and work through the list with
your admins.

## Pre-event checklist

- Project exists with the correct field slip prefix
- Slips printed (MO-style from Admin → Field Slips, or DBG-style with
  your DBG curator — the latter arranged with the development team in
  advance)
- Membership open, or every collector pre-enrolled
- Location/date constraints loose enough not to eject real
  observations
- Aliases entered (sites, walks, collector initials)
- Every reviewer is a project admin
