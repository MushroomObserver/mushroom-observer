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

  # Safely coerces an already-scalar param value (e.g. from a
  # `.permit`-filtered hash, so String or nil -- never a nested Hash)
  # to an Integer. A non-numeric String degrades to nil rather than
  # raising, since this sits at a request boundary handling untrusted
  # input.
  def safe_integer(value)
    Integer(value) if value.is_a?(String) || value.is_a?(Integer)
  rescue ArgumentError
    nil
  end
end
