# frozen_string_literal: true

# `string_param` for both controllers and Phlex views -- both expose
# `params`. Reads a request param only when it's a scalar String, else
# nil.
#
# Automated scanners send a scalar param as a nested hash (e.g.
# `?letter[foo]=bar`), which Rails parses into an
# ActionController::Parameters object. Passing that to a String-only
# sink -- an ActiveRecord bind, a Literal `String` prop, `String#to_sym`
# -- raises a 500. Coercing a non-scalar to nil treats the garbage shape
# as "not given" so the request is served normally.
module ScalarParams
  def string_param(key)
    value = params[key]
    value if value.is_a?(String)
  end
end
