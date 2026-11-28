# Floating point columns are double precision

**Every floating point column in MO's schema is double precision.**
Declare a new one as `t.column(:name, :double)`, not `t.float(:name)`.

## Why

`t.float` on MySQL means `FLOAT` — single precision. MySQL serves a
single-precision value to a client at single precision, so a value
read back does not compare equal to the row it came from:

```sql
SELECT f, CAST(f AS DOUBLE), f = 0.58 FROM t;
-- 0.58   0.5799999833106995   0
```

Any query seeded from a stored value then misses. Two instances found
so far:

- `Query::Modules::Seek`'s keyset pager compared a plucked value
  against its own row, matched it, and returned the current record as
  the next one — Next/Prev stuck on a quality-ordered index (#5796).
- `Naming.confidence`'s single-value form is
  `where(vote_cache: min..min)`, which matches nothing for a value
  single precision cannot hold.

A `DOUBLE` survives the round trip to the client and back into a
literal, so both work. The nine columns that were single precision
were converted in `20261128120000_convert_float_columns_to_double.rb`.

## How it reads in `schema.rb`

The schema dumper writes a double as `t.float "name", limit: 53`,
because Rails registers both MySQL types as `Type::Float` and
distinguishes them by limit (24 vs 53). So the word "double" does not
appear in `schema.rb`, and a bare `t.float "name"` line there is the
thing to look for.

`t.float(:name, limit: 53)` produces the same column as
`t.column(:name, :double)`. Prefer the second — it says what it means
at the declaration site.

## Enforcement

`test/style/no_single_precision_float_columns_test.rb` reads the
loaded schema and fails on any column whose type is float with a
limit below 53. It reads the schema rather than the migration files,
so a column added by any route is covered.

## Scope

This is about floating point, not about picking a numeric type.
Latitude, longitude and box area are `decimal(15,10)`, and money is
`decimal(12,2)`; a column that wants an exact decimal value should
stay decimal rather than become a double.
