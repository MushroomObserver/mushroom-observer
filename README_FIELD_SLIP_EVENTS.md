# Field-Slip Events: Developer Notes

Technical details for supporting a field-slip event (foray, fair) that
aren't documented elsewhere in the code base. The *project admin*
guide — how to set up and run an event without touching code — is an
MO Article on the site (draft: `doc/field_slip_event_admin_article.md`);
admins reach the development team at webmaster@mushroomobserver.org,
and the notes below are for fielding those questions.

## Registering a slip template for a new event

The machine-reading pipeline selects a printed layout by the project's
`field_slip_prefix`. Layouts are registered in `FieldSlip::Template`
(`app/classes/field_slip/template.rb`): MO's own slips need nothing; a
new event using DBG-style voucher slips needs its prefix added to
`PROJECT_TEMPLATES` there. Issue #5027 tracks making this DB-defined
and self-serve; until then it is a one-line code change plus deploy.

## Event support scripts

Both are documented in their own headers; short form:

- `bin/rails runner script/field_slip_event_report.rb PROJECT_ID` —
  read-only post-event cleanup queue (dubious GPS, free-text
  localities, missing GPS, unresolved iNat notes, empty slips,
  cross-prefix observations).
- `bin/rails runner script/attach_slips_from_extracts.rb` (dry-run by
  default, `--apply`) — attaches slip-less observations whose
  machine-read found a code the QR decode missed.
- `bin/rails runner script/copy_project_aliases.rb FROM_ID TO_ID`
  (dry-run by default, `--apply`) — seeds one project's aliases from
  another (last year's event, a sibling project). Admins can only add
  aliases one at a time through the UI, so bulk seeding is a
  dev-assisted step.

## Mechanics behind common admin reports

- **"The slip attached but the observation isn't in the project."**
  Constraint violation: the slip and its observations are in the
  project together or not at all (#4932 invariant 2), so a violating
  observation takes its slip out of the project ("spare" slip,
  `project_id` nil). The review-save reconcile restores both — via the
  printed prefix — once the observation's data satisfies the
  constraints. See `Images::FieldSlipExtractsController` and
  `FieldSlip::Attacher`.
- **"The scan silently did nothing for a collector."** Closed project:
  using a slip only auto-enrolls for `open_membership` projects. A
  non-member's slip on a closed project comes out as a project-less
  spare.
- **"The form prefilled a locality from the wrong region."** A form
  opened with a field slip code defaults the locality from the slip
  project's location (`apply_field_slip_location`), overriding the
  usual previous-observation default. Without a code the old default
  applies, but a resulting constraint problem surfaces in the pre-save
  project alert rather than silently keeping the observation out.
- **Slip reading/review is admin-gated** (project admins + site
  admins): each read is a paid API call and writes to observations the
  reviewer may not own. Recorders who should review need admin, not
  member.
