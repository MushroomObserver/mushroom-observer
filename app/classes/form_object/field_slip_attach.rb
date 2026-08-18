# frozen_string_literal: true

# Backs `Observations::FieldSlips::Form` -- a single code field.
# Decorative in the sense that the actual submitted param is the bare
# top-level `field_code` (read directly by
# `ObservationsController::FieldSlips#field_code`, shared with the
# full observation form), not a namespaced `field_slip_attach[...]`
# value -- this FormObject exists only for Superform's `<form>` tag
# machinery.
class FormObject::FieldSlipAttach < FormObject::Base
  attribute :field_code, :string
end
