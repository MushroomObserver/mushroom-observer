# Index filter params — generic, no per-controller method needed

## How it works

`ApplicationController::Indexes#build_index_with_query` dispatches every model index generically now. There is no `index_active_params` allowlist and no per-param subaction method — any param a controller's `Query` subclass recognizes (its `query_attr` names and their `param_alias` shortcuts) is automatically a live top-level index filter:

```
/observations?project=123
/observations?by_user=456&by=date
```

Dispatch priority, per request:

1. `:pattern`, if the model's Query recognizes it and it's present — routed through `PatternSearch`'s keyword parsing (`ApplicationController::Indexes#pattern`), not the generic resolver.
2. Any other recognized param present — resolved generically via `create_query_from_url_params`. Multiple recognized params combine into one query (e.g. `?by_user=X&has_notes=true` filters by both), unlike the old subaction dispatch, which only ever acted on the first param it happened to list.
3. `:by`/`:q`/`:id` (`sorted_index`) — only when no other recognized param is present.
4. Otherwise, the unfiltered index.

## Adding a new filter shortcut

Just declare the `query_attr` (with a `param_alias:` if it needs a shorter URL name than the attr itself) on the model's `Query` subclass. No controller method, no array entry, nothing else to wire up:

```ruby
# app/classes/query/observations.rb
query_attr(:projects, [Project], param_alias: :project, redirect_to: :model_index)
```

`?project=123` and `?projects[]=123` both work immediately, everywhere that model's index is reachable.

## When a controller still needs to inject something

A few controllers need a param that isn't really a URL-level choice — e.g. `Observations::IdentifyController` always filters to the signed-in user's needs-naming queue, filtered or not. Force it onto `params` in the action itself, before `build_index_with_query` runs, so it participates in dispatch like any other recognized param:

```ruby
def index
  params[:needs_naming] ||= "1"
  build_index_with_query
end
```

This is the only kind of controller-side involvement that should exist for index filtering. Don't write a per-param method or a `case`/`if` chain dispatching by param name — that's the pattern this mechanism replaced.

## History

This mechanism replaced `index_active_params` (a per-controller array requiring a same-named method for every non-`:by`/`:q`/`:id` shortcut) — see issue #5140 and the parent issue #4636. If you're reading old context (a PR description, a comment, a memory entry) that mentions `index_active_params`, it's describing the pre-#5140 state; the method no longer exists anywhere in the codebase.
