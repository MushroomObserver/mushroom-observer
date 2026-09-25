# Docker

The `Dockerfile` is multi-stage: a shared `base`, then `development` and
`production` targets. Everything below through "Rebuilding after Gemfile
changes" covers `development`, the target `compose.yaml` builds. See
"Production image" at the bottom for the `production` target.

## Setup (first time)

```bash
docker compose build
docker compose up -d
```

The container will install gems, wait for the database, and run `db:prepare`
automatically on every start. To load fixtures and regenerate the language
file (required before running tests):

```bash
docker compose exec web bin/rails db:fixtures:load
docker compose exec web bin/rails lang:update
```

---

## Running the app

```bash
# Start (background)
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f web

# Rails console
docker compose exec web bin/rails console
```

The app is available at http://localhost:3000.

---

## Running tests

```bash
# Full suite
docker compose exec web bin/rails test

# Single file
docker compose exec web bin/rails test test/models/observation_test.rb

# Single test by name
docker compose exec web bin/rails test test/models/observation_test.rb -n test_scope_needs_naming

# System tests (requires Chromium — included in the image)
docker compose exec web bin/rails test test/system/
```

---

## Database operations

```bash
# Reset database (wipes all data, re-runs schema + fixtures)
docker compose down -v
docker compose up -d
docker compose exec web bin/rails db:fixtures:load
docker compose exec web bin/rails lang:update

# Run pending migrations only
docker compose exec web bin/rails db:migrate

# Open a MySQL shell
docker compose exec db mysql -u mo -pmo_password mo_development

# Load a gzipped DB image into the containerized DB
gunzip -c <file> | docker compose exec -T db mysql -u mo -pmo_password mo_development
```

---

## Rebuilding after Gemfile changes

```bash
docker compose build
docker compose down && docker compose up -d
```

---

## Production image

`docker compose build`/`docker compose up` above always build
`development` explicitly, via `compose.yaml`'s `target:`. A bare `docker
build .` with no `--target` now defaults to the last stage, `production`
-- build `development` explicitly if that's what you want outside
compose:

```bash
docker build --target development -t mo-dev .
docker build --target production -t mo-production .
```

`production` differs from `development`: `RAILS_ENV=production`, gems
installed in deployment mode (`BUNDLE_DEPLOYMENT=1`,
`BUNDLE_WITHOUT=development:test`), the app code is `COPY`'d into the
image (no bind mount -- production ships a self-contained image), and no
Chromium.

Assets are **not** precompiled at build time -- MO's `acts_as_versioned`
models (`Location`, `Name`, `LocationDescription`, `NameDescription`,
`GlossaryTerm`, `TranslationString`) need a live, reachable database to
load, which a build machine doesn't have. `docker/entrypoint.production.sh`
precompiles at container start instead, gated on the server role's start
command (`bin/rails server`) so a Solid Queue worker role sharing this
image with a different `CMD` (`bin/jobs`) doesn't race it.

### Running the production image locally

Needs a reachable MySQL and a `RAILS_MASTER_KEY` -- generate a throwaway
local credentials file for this rather than using the production key:

```bash
docker run --rm -p 3000:3000 \
  -e DATABASE_HOST=<mysql host> \
  -e DATABASE_USERNAME=mo -e DATABASE_PASSWORD=mo \
  -e RAILS_MASTER_KEY=<key> \
  mo-production
```

The entrypoint waits for the database, runs `db:prepare`, precompiles
assets on first start, then starts Puma. Puma binds TCP on `$PORT`
(default `3000`) and logs to STDOUT, and the Rails app logger does too
(`config/environments/production.rb`) -- both key off `ENV["PORT"]` to
distinguish this from the current bare-metal deploy (a Unix socket,
file-based logs under `/var/web/mushroom-observer`), which stays
untouched when `PORT` isn't set.

Env vars the production target reads (see `db/docker/database.yml`):
`DATABASE_HOST`/`DATABASE_NAME`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/
`DATABASE_POOL`, `CACHE_DATABASE_NAME`, `PORT`, `WEB_CONCURRENCY`,
`RAILS_MAX_THREADS`.

This covers building/running/testing the production target locally --
it's not a deploy guide. Front-door/SSL, secrets, image registry, and
disposable environments are #5345's open scope, not settled here.
