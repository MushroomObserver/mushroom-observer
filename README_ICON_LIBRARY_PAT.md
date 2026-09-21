# CI access to the private icon-library repo

`MushroomObserver/icon-library` is a private repo holding licensed
Glyphicons source material and the `mo-icons.svg` sprite built from
it. This repo is public and MIT-licensed, so `mo-icons.svg` -- even
though it's a curated derivative, not the original design files --
isn't committed here. CI needs its own way to fetch it for tests that
depend on it.

That's `ICON_LIBRARY_PAT`: a fine-grained GitHub Personal Access
Token, stored as a repository secret on `mushroom-observer`, scoped to
**read-only** access on `icon-library` alone. `.github/workflows/
ci_rails.yml`'s `test` job uses it to sparse-clone `icon-library` into
`vendor/assets/images/icons/` at the start of each run. The sprite is
required, not optional: `app/assets/config/manifest.js` links it, so
without it every test that renders a page fails with
`Sprockets::FileNotFound`. If the secret is *missing* (deleted, or a
`pull_request` run from a fork, which GitHub doesn't expose repo
secrets to), the step fails immediately with a message saying so,
rather than letting the suite break later in a way that looks
unrelated -- see its comment in `ci_rails.yml`.

**The token has to live in two secret stores.** Workflows on
Dependabot's PRs read *Dependabot* secrets, not Actions secrets, so a
PAT stored only under Actions leaves `secrets.ICON_LIBRARY_PAT` empty
on every Dependabot run. Add the same value in both places (step 8
below).

An *expired* token fails a step earlier than a missing one, and with a
different message: the secret variable is still non-empty, just
carrying a token GitHub no longer accepts, so `git clone` fails with a
bad-credentials error. Either way the `test` job stops at the fetch
step on every run -- worth knowing so it doesn't look like an
unrelated regression when it happens.

Fine-grained tokens require an expiration date (GitHub doesn't allow
one that never expires), so this **will** need to be regenerated
periodically -- likely once a year. Renew it in advance if you can;
if CI starts failing at the "Fetch icon-library sprite" step for no
apparent code-related reason, this is the first thing to check.

## To create or renew it

Needs a GitHub account with read access to `MushroomObserver/icon-library`
(ask an MO admin if you don't have it) and admin access on the
`mushroom-observer` repo (to set the secret).

1. On `github.com`: your avatar (top right) -> **Settings** ->
   **Developer settings** (bottom of the left sidebar) -> **Personal
   access tokens** -> **Fine-grained tokens** -> **Generate new
   token**.
2. Name it something identifiable, e.g. `mushroom-observer CI -
   icon-library read`.
3. Set an expiration -- a year is reasonable.
4. **Resource owner**: `MushroomObserver` (the org -- this is what
   makes `icon-library` selectable at all).
5. **Repository access**: "Only select repositories" -> `icon-library`.
6. **Permissions** -> **Repository permissions** -> **Contents** ->
   **Read-only**. That's the only permission a `git clone` needs --
   don't grant more.
7. **Generate token**. GitHub shows the value exactly once -- copy it
   now, you won't be able to see it again.
8. Store it twice, under the same name, with the same value:
   - `github.com/MushroomObserver/mushroom-observer/settings/secrets/actions`:
     **New repository secret** (or edit the existing `ICON_LIBRARY_PAT`
     if renewing) -> name it `ICON_LIBRARY_PAT` -> paste the token
     value -> **Add secret** (or **Update secret**). This covers
     branches pushed to this repo.
   - `github.com/MushroomObserver/mushroom-observer/settings/secrets/dependabot`:
     the same again. This covers Dependabot's PRs, which can't read
     the Actions store.

Never paste the token value anywhere else -- not into a commit, an
issue, a PR description, or a chat with an AI assistant. It only ever
needs to exist in GitHub's own secret-storage form.

## Verifying it worked

Push anything to a branch with an open PR (or open a new one) and
check the "Fetch icon-library sprite" step in the `test` job. The
clone itself is silent on success (`--quiet`), so don't look for a
"cloned successfully" message from git -- instead check:

- The step's own log ends with `Cloned icon-library -- mo-icons.svg
  present.`, not the `ICON_LIBRARY_PAT not set` skip message.
- The step is marked passed, with no `::warning::` annotation about a
  missing `mo-icons.svg` (that would mean the clone worked but
  icon-library's `main` branch doesn't have the file -- a different
  problem, on the icon-library side, not the PAT).
