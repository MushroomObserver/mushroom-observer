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

  # Force Superform to spoof PATCH/PUT via the hidden _method field
  # (route only accepts put/patch) -- a literal method="put" on the
  # <form> tag itself isn't valid HTML5 and silently submits as GET.
  def persisted?
    true
  end
end
