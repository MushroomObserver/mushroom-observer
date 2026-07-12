# No raw SQL

**Hard rule: never write raw SQL strings in application code.** No
`Model.connection.execute("SELECT ...")`, no `Model.connection.select_all(<<~SQL)`,
no string-interpolated `WHERE`/`JOIN` clauses. Use ActiveRecord query methods
or Arel instead.

```ruby
# BAD - raw SQL string, even via ActiveRecord::Base.connection
sql = <<~SQL.squish
  SELECT obs.id, obs.vote_cache
  FROM observations obs
  JOIN namings n ON n.id = obs.name_id
  WHERE ABS(IFNULL(obs.vote_cache, 0)) < 0.01
SQL
ActiveRecord::Base.connection.execute(sql).to_a

# GOOD - ActiveRecord relation / Arel
Observation.joins(:namings)
           .where(Observation[:vote_cache].abs.lteq(0.01))
```

This applies everywhere: models, jobs, scripts, rake tasks. A rewrite from a
raw-SQL script (or raw `mysql` CLI script) into a Solid Queue job is exactly
the place to make this fix, not to carry the raw SQL forward unchanged.

## Why

- Raw SQL bypasses Rails' SQL-injection escaping discipline - every
  interpolated value needs manual sanitization that AR/Arel give you for
  free.
- Raw SQL doesn't participate in AR's query composition (`.merge`,
  `.or`, eager-loading, scopes) - a raw query is a dead end you can't
  build on incrementally.
- Raw SQL is untyped output (`select_all` returns arrays of raw column
  values, not model instances), forcing manual column-index/name
  bookkeeping (`row["n"]`, `row[0]`) instead of `record.attribute`.
- MySQL-specific raw SQL (`IFNULL`, backtick-quoted `rank`) ties the
  codebase to one database dialect for no reason AR abstraction wouldn't
  otherwise take care of.

## Where this has come up

The crontab-to-Solid-Queue job conversions (issue #4726) are the main
place this surfaces, since several of the original cron scripts were
written as raw SQL/raw `mysql` CLI scripts for performance reasons that
predate more of MO's ActiveRecord/Arel scopes existing. When porting one
of these into a job, rewrite the query in AR/Arel as part of the same PR
- don't defer it.
