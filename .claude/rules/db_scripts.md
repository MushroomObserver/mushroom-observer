# Database checkpoint scripts — where they live

Scripts for downloading and restoring a stripped production-database
snapshot into local dev live in `db/`, not `script/`:

- `db/download_checkpoint` — downloads yesterday's production DB
  backup from `images.mushroomobserver.org` via `scp` (requires an SSH
  account on that server), saves it as `checkpoint.gz` in the repo
  root, then calls `db/strip_checkpoint`.
- `db/strip_checkpoint` — imports the **already-present**
  `checkpoint.gz` (repo root) into MySQL as `mo_development` and runs
  `db/clean.sql` against it. Does **not** download anything itself —
  that's exactly why it's a separate script from `download_checkpoint`:
  if the scp succeeded but the import/clean step failed (or `clean.sql`
  itself changes), re-run `db/strip_checkpoint` alone against the
  already-downloaded file. No need to re-run `download_checkpoint` /
  re-fetch over SSH unless `checkpoint.gz` itself is missing or stale.
- `db/clean.sql` — strips passwords, API keys, emails, original
  filenames, and private GPS data from the imported checkpoint. Piped
  into `mysql`'s stdin (`mysql ... < db/clean.sql`), not passed via
  `-e "source ..."` — `source` is a client-REPL-only directive, not
  SQL the server understands, and errors with `ERROR 1064 (42000)` if
  passed to `-e` (fixed 2026-07, see git blame on `strip_checkpoint`).

Documented for end users in `README_MACOSX_NOTES.md` ("Load a MO
database backup") as `db/download_checkpoint`.

**Deliberately kept in `db/`, not `script/`.** `script/` is a flat pile
of dozens of unrelated one-off scripts with no existing subdirectory
convention — introducing a `script/db/` subdirectory there would be
the first exception to that flat pattern, not a fit with it. `db/` is
already Rails' idiomatic home for "stuff about the database" (it holds
hand-written scripts like `seeds.rb`, not just auto-generated
`schema.rb`/migrations), and these three scripts are tightly bound to
that domain. Moving them to `script/` would make `script/` fuller
without making `db/` any clearer — considered and rejected in a
2026-07 conversation.

## When the dev DB is missing rows / `NoMethodError` on `nil` associations

If you hit something like `NoMethodError (undefined method 'foo' for
nil)` on a `belongs_to` association (e.g. `Observation#name` being
`nil` despite `name_id` being set) — check `Name.minimum(:id)` /
`Observation.joins("LEFT JOIN names ON names.id = observations.name_id")
.where("names.id IS NULL").count` (adjust model/table as needed) before
assuming it's a code bug. A local dev DB restored from a partial/
truncated snapshot can have dangling foreign keys where the referenced
row's ID range was never imported. The fix is `db/download_checkpoint`
above, not a code change.
