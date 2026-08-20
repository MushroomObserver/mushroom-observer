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
  def query_attr(attr, accepts, param_alias: nil, default_order: nil)
    attribute(attr, :query_param, accepts:, param_alias:, default_order:)
  end
end
