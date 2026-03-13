# frozen_string_literal: true

#
#  = Extensions to Class
#
class Class
  # Convenience method for setting Query subclass attributes.
  # These use a custom attribute type defined in app/types/query_param_type.rb
  def query_attr(attr, accepts)
    attribute(attr, :query_param, accepts:)
  end
end
