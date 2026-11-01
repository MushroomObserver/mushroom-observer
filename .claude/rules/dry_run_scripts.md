# Dry-run vs. apply convention for scripts and rake tasks

Every script that can change data runs as a **dry run by default** and
requires an explicit opt-in to write. The opt-in spelling depends on the
invocation style — do not mix them:

## `bin/rails runner` scripts (backfills, one-offs): trailing `--apply`

```bash
# Dry run (default — reports what WOULD change, writes nothing):
bin/rails runner script/fix_whatever.rb

# Live run:
bin/rails runner script/fix_whatever.rb --apply
```

Requirements for the script:

1. **Dry-run is the default.** `--apply` is the only way to write.
2. **Reject unknown argv with a non-zero exit.** A typo (`--aply`) must
   abort loudly, never silently degrade to a dry run — the operator
   would believe they applied.
3. **Dry-run output says so**, states that nothing was written, and
   echoes the exact command to apply:
   `Dry run - nothing written. To apply: bin/rails runner script/fix_whatever.rb --apply`

Why a flag and not an env var here: a flag is per-invocation by
construction (no `export` can leave it armed for a later script), a
typo'd flag is detectable while a typo'd env var never is, it shows up
in the usage line and `ps` output, and the natural promotion workflow
is up-arrow + append ` --apply`.

Use `--apply`, not `--commit` (collides with git vocabulary) and not
`--force`/`--go`.

## Rake tasks: inline `APPLY=1` prefix

```bash
# Dry run:
bin/rails some:task

# Live run:
APPLY=1 bin/rails some:task
```

Rake's argv passthrough (`rake foo -- --apply`) is clumsy, and env vars
are the established rake convention (`VERSION=`, `COUNT=`). Same
semantics: absent → dry run; the task's `desc` documents `APPLY=1`.

**Always write `APPLY=1` inline on the command line, never `export` it**
— an exported APPLY silently arms every later task in the shell that
honors the same variable.

## When a constraint depends on a repair

Adding a unique index (or a NOT NULL, or a foreign key) to data that
does not satisfy it yet needs the repair to run first. MO keeps the
repair in a script, not the migration: a repair that destroys records,
moves references between them, or wants a human to read its dry run is
a production operation, and a migration gives you no dry run, no
ID-level report to review, and runs on every developer's machine and
inside the deploy.

What the migration does instead is **refuse to run until the repair
has happened**, naming the command:

```ruby
def up
  refuse_until_repaired
  add_index(...)
end

def refuse_until_repaired
  duplicates = MigrationExternalLink.where(...).group(...).having(...).count
  return if duplicates.empty?

  raise("#{duplicates.size} rows still violate this. Run the repair " \
        "first: bin/rails runner script/whatever.rb --apply")
end
```

That gives the guarantee a repair-inside-the-migration would: after
`db:migrate` succeeds, the database satisfies the constraint. A
developer who has not run the repair gets told which script to run
rather than a duplicate-key error, and the script is in the repo, so
nothing has to be fetched from anywhere.

Two details:

- **Do not use application models in a migration**, for the check or
  anything else. They keep changing after the migration is written.
  Define a minimal class inside the migration
  (`class MigrationExternalLink < ActiveRecord::Base; self.table_name =
  "external_links"; end`) so it keeps meaning what it meant.
- **Say in the migration's comment what the repair was**, since the
  two are separated. See
  `db/migrate/20260930120000_one_import_link_per_remote_record.rb` and
  `script/merge_duplicate_inat_images.rb` for the worked pair.

A small, safe, model-free data change (normalising a string column,
say) can still sit in the migration as ~16 of MO's migrations do. The
test is whether the change is destructive and whether anyone would want
to read what it did before it did it.

## Scope

This covers the dry-run/apply toggle only. The rest of the backfill
conventions (idempotent, ID-level reporting, periodic stderr progress)
are unchanged.
