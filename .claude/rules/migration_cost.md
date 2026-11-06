# Knowing what a migration will cost before it runs in production

A schema migration runs inside the deploy, with the site down. A
column change that is metadata on one column and a full table rebuild
on the next looks identical in the migration source, so the cost has
to be measured, not read off the code. `20261014140000` converted 76
varchar columns to utf8mb4: 61 of them took under 40ms each, and
`external_links` alone took 459 of the 497 seconds, holding the site
down for seven and a half minutes.

## What makes a column change slow

MySQL does a charset widening as pure metadata when it can accept
`ALGORITHM=INPLACE`, and as a full table-and-index rebuild
(`ALGORITHM=COPY`) when it cannot. Two things force the rebuild:

- **The varchar length prefix widens.** A varchar needs one length
  byte up to 255 bytes of capacity and two above it. `varchar(64)`
  holds 192 bytes as utf8mb3 and 256 as utf8mb4, so the prefix goes
  from one byte to two, and MySQL only supports that with a copy. The
  band is `limit` **64 through 85**: below 64 both widths fit in one
  byte, above 85 both already need two.
- **Any index covers the column.** The key length changes, so the
  index is rebuilt. This applies at any `limit`, inside the band or
  not.

Everything else — `varchar(1024)` unindexed over 668k rows — is
metadata, in tens of milliseconds.

## Check it before the deploy, not during

Run the exact DDL against a scratch copy with the algorithm named. A
refusal is the answer; nothing has to complete:

```sql
ALTER TABLE t MODIFY col varchar(64)
  CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci, ALGORITHM=INPLACE;
-- ERROR 1846: ALGORITHM=INPLACE is not supported.
--             Reason: Cannot change column type INPLACE.
```

`INPLACE` accepted means metadata. `INPLACE` refused means the table
and every index on it get rebuilt, and the cost scales with
`data_length + index_length`, which `information_schema.tables`
reports. `external_links` is 166MB of data against **526MB of
indexes** — more index than data — over 2.1M rows, which is why it
dominated.

## Local timings do not transfer — measure the ratio once

The local dev database is a production snapshot, so row counts match
and a slow migration *is* slow locally. It is just not alarming at
local speed. The same five statements, same 2.1M rows:

| | local (9.6, arm64) | production |
| --- | --- | --- |
| five separate ALTERs, as Rails issued them | 63.2s | 458.7s |

That is a **7.3x** factor. A minute locally is seven and a half in
production. Scale local numbers by it before deciding a migration is
cheap enough to run inside a deploy, and re-measure the factor when
the database host changes.

## Batch every DDL statement against one table into one ALTER

Rails issues one `ALTER TABLE` per migration method call, and each one
pays its own full rebuild. `20261014140000` issued five against
`external_links` — two `remove_column`, two `change_column`, one
`change_table` — and rebuilt the table five times. Measured on the
same replica:

| | local | scaled to production |
| --- | --- | --- |
| five separate ALTERs | 63.2s | ~459s (actual) |
| one combined ALTER | 19.8s | ~144s |
| one combined ALTER, redundant index dropped first | 17.5s | ~127s |

So wrap everything touching one table in a single
`change_table(:t, bulk: true)`, and use `remove_columns` rather than
repeated `remove_column`. Pulling a table's entries out of a generic
column loop to do this is worth it.

**Re-adding a generated column's index under its old name needs the
key dropped explicitly in the same statement.** `DROP COLUMN` takes
the index with it, but within one `ALTER` MySQL still rejects the
`ADD UNIQUE KEY` as a duplicate name:

```
ERROR 1061 (42000): Duplicate key name 'index_external_links_on_import_source'
```

Drop the key by name first, then the column.

## While it is running

`information_schema.processlist` answers "why is this taking so long"
live, and the `mo` user has `PROCESS` on production:

```sql
SELECT id, time, state, LEFT(info, 60)
FROM information_schema.processlist WHERE info LIKE 'ALTER%';
```

`state = "copy to tmp table"` means MySQL chose `COPY` and is
rebuilding; the row's `time` is how long it has been at it. The
`performance_schema` stage tables would give a percentage, but `mo`
is not granted them.

`COPY` does not permit concurrent DML. Reads continue, writes to that
table block for the whole rebuild — for `external_links` that is every
iNat import and reflection link write.

## When a rebuild is unavoidable and too long for a deploy

A table that has to be rebuilt will cost what it costs. The options
are to run it out of band with the site up, accepting that writes to
that one table block for the duration, or to reach for an external
online-schema-change tool. Neither has been needed yet; the point is
to decide before the deploy starts, not while watching it.
