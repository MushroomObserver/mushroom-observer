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

`:by` is in `recognized_params` too (`Query#order_by` declares `param_alias: :by`), but it's deliberately excluded from step 2 and handled by `sorted_index` instead. A "sort by X" link submits only `?by=X`, relying on `find_or_create_query` to look up the existing session/bookmarked query first and merge the new sort onto its full param set -- preserving whatever filter is already active. The generic resolver in step 2 never does that lookup; it builds params solely from what's submitted in the current request, with nothing carried over from a prior query. (Both paths end up saving their result to session afterward, via the same shared `update_stored_query` step in `filtered_index` -- that part's identical. The difference is only that the generic path's query never inherited the previous one's filters to begin with.) Folding `:by` into step 2 would mean every sort-link click builds a filter-less query from scratch. `sorted_index` also does `:by`-specific validation (`order_by_or_flash_if_unknown`, a distinct flash message from the generic path's) and legacy value remapping (`map_past_bys`). `:q`/`:id` aren't real recognized params at all -- `:q` is the forwarded/bookmarked-query meta-param, `:id` is pagination-cursor positioning only -- so excluding them from step 2 is defensive, not load-bearing.

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
