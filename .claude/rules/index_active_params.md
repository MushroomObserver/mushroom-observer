# `index_active_params` — Deprecated, Do Not Extend

## What it is

`index_active_params` is a method on controller classes (overriding `ApplicationController::Indexes`) that declares a list of "shortcut" URL params the index action accepts directly — e.g. `?project=123`, `?by_user=456`, `?pattern=foo`. The framework translates these into `Query` objects behind the scenes.

Example of what **not** to add:

```ruby
# ❌ DO NOT ADD — deprecated pattern
def index_active_params
  [:pattern, :project, :by_user, :by, :q, :id].freeze
end
```

## Why it is deprecated

MO's observation index (and all other model indexes) use the `Query` system for filtering. Queries are encoded directly in URLs as nested params:

```
/observations?q[model]=Observation&q[projects][]=123
/observations?q[model]=Observation&q[by_users][]=456&q[order_by]=date
```

These URLs are fully self-contained and stable — any user with the URL lands on the exact same result set, no session or database lookup required.

`index_active_params` shortcuts (`?project=123`) are a parallel path that pre-dates the current Query URL format. They exist only for backward compatibility with old links. Every shortcut in the list is a second way to express something the Query system already handles natively. The plan (tracked in GitHub issue #4636) is to remove all of them.

## What to do instead

**Never** add a new `index_active_params` entry or a new `def index_active_params` override to any controller.

To link to a filtered index, build the Query and use `redirect_with_query` (in controllers) or `add_q_param` (in views/helpers) to produce the proper `?q[...]` URL:

```ruby
# In a controller action — redirect to filtered observations
query = Query.lookup(:Observation, projects: [@project])
redirect_with_query(observations_path, query)

# In a view — link to filtered observations
link_to("Project obs", add_q_param(observations_path, query))
```

The `?q[model]=Observation&q[projects][]=123` URL produced this way is the stable, correct form. It does not require a database record or session to reconstruct — all params are in the URL itself.

## The sweep

Issue #4636 tracks removing every existing `index_active_params` override across all controllers. When that sweep lands, the base method in `ApplicationController::Indexes` will be deleted too.

Until then: leave existing entries alone (removing them requires coordinated route/link updates), but **add nothing new**.
