# One-time scripts

A script meant to run once against production (a data backfill, a
one-shot cleanup ahead of a migration) does not belong in the app
repo. It has no test coverage, no reviewer benefit from staying in
git history past the run, and its presence just adds to the pile of
scripts a future reader has to figure out whether they're still
needed.

This directory is gitignored (see `.gitignore`) except for this
README, so it's a place to develop such a script locally without
committing it. Workflow:

1. Write and test the script here, against a local dev DB checkpoint.
2. `scp` it to the production box.
3. Run it there (dry run first, then `--apply`).
4. Delete it from production once it's done its job.
5. Delete the local copy too, once it's no longer needed -- there's
   nothing to clean up in git since it was not tracked.

A reusable script -- run periodically, with ongoing value and test
coverage -- belongs in `script/` proper, not here.
