# frozen_string_literal: true

#
#  = Extensions to Class
#
class Class
  # Convenience method for setting Query subclass attributes.
  # These use a custom attribute type defined in app/types/query_param_type.rb
  #
  # `param_alias:` declares a singular scalar URL param name (e.g. `:project`)
  # that resolves to this attr (e.g. `?project=123` -> `projects: [123]`).
  # See `Query.param_aliases`/`Query.resolve_param_aliases`.
  #
  # `default_order:` overrides the class-wide `default_order` when this attr
  # is present in `params` and no explicit `order_by` was given. See
  # `Query#default_order`.
  #
  # `always_index:` (default true) controls whether resolving this attr's
  # `param_alias:` forces `always_index: true` on the display opts (so a
  # single-result match shows the index instead of auto-redirecting to
  # that one result) -- see
  # ApplicationController::QueryParams#create_query_from_url_params.
  # Set false on an attr whose single-match auto-redirect is
  # intentional/tested. Doesn't affect the record-lookup/flash/redirect
  # behavior on a bad id, only whether a *found* record forces the index.
  #
  # `redirect_to:` (default `:own_index`) picks where a record-backed
  # `param_alias:` sends the user when the id doesn't resolve.
  # `:own_index` redirects back to the calling controller's own index.
  # `:model_index` redirects to the *looked-up* model's own index instead
  # (matches shortcuts built on `find_or_goto_index` -- e.g.
  # `ObservationsController::Index#by_user` sending a bad id to `/users`).
  def query_attr(attr, accepts, **)
    attribute(attr, :query_param, accepts:, **)
  end
end
