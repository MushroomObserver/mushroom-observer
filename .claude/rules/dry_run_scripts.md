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

## Scope

This covers the dry-run/apply toggle only. The rest of the backfill
conventions (idempotent, ID-level reporting, periodic stderr progress)
are unchanged.
