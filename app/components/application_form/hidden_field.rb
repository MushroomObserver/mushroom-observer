# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Renders a bare `<input type="hidden">` for a Superform field or
  # `FieldProxy`. Use this when you need a hidden input but can't reach
  # the `hidden_field` form helper — typically for `FieldProxy`-backed
  # non-model fields rendered inside an `ApplicationForm` subclass.
  #
  # The form-attached helper `ApplicationForm#hidden_field` is preferred
  # for model fields; reach for this class only when the helper doesn't
  # apply.
  #
  # @example FieldProxy-backed hidden input
  #   proxy = ApplicationForm::FieldProxy.new(nil, "old_desc_id", id)
  #   render(ApplicationForm::HiddenField.new(proxy))
  #
  # @example Explicit value override
  #   render(ApplicationForm::HiddenField.new(field, value: "x"))
  class HiddenField < Phlex::HTML
    def initialize(field, **attributes)
      super()
      @field = field
      @attributes = attributes
    end

    def view_template
      # Rails' `hidden_field_tag` defaults `autocomplete="off"` (browsers
      # otherwise repopulate hidden fields on back-button, which can
      # break stale-state-sensitive forms). Match that default; let the
      # caller override via `autocomplete:`.
      input(
        type: "hidden",
        id: @field.dom.id,
        name: @field.dom.name,
        value: @attributes.fetch(:value) { @field.value },
        autocomplete: "off",
        **@attributes.except(:value)
      )
    end
  end
end
