# Docker Development

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
```

---

## Rebuilding after Gemfile changes

```bash
docker compose build
docker compose down && docker compose up -d
```
