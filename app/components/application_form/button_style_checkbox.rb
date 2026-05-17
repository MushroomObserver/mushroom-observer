# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap 3 button-styled checkbox: a `<label class="btn …">`
  # wrapping an `<input type="checkbox">` plus arbitrary block content
  # (the visible text/icons). NO `.checkbox` div wrap — that wrap is
  # for vertical checkbox-list layout; this component is for
  # checkboxes that look like buttons (BS3's
  # `.btn-group[data-toggle="buttons"]` pattern, or standalone
  # button-styled checkboxes scattered across a filter UI).
  #
  # Parallel of `ButtonStyleRadio`. Same constructor shape, same
  # caller ergonomics — just emits `type="checkbox"` and supports
  # name-array shapes like `q[type][]` for multi-select filters.
  #
  # Standalone (no Superform context) — takes raw HTML kwargs rather
  # than a `Field` / `FieldProxy`, since the call sites (filter UIs,
  # in-form toolbars) don't always have a form context available.
  #
  # @example
  #   render(Components::ApplicationForm::ButtonStyleCheckbox.new(
  #     name: "q[type][]", value: "observation",
  #     id: "type_observation", checked: types.include?("observation"),
  #     label: { class: "btn btn-default filter-checkbox" }
  #   )) do
  #     plain "Observations"
  #   end
  class ButtonStyleCheckbox < Phlex::HTML
    include Components::TrustedHtml

    # rubocop:disable Metrics/ParameterLists
    def initialize(name:, value:, id:, checked: false,
                   label: {}, **input_attrs)
      # rubocop:enable Metrics/ParameterLists
      super()
      @name = name
      @value = value
      @id = id
      @checked = checked
      @label_attrs = label
      @input_attrs = input_attrs
    end

    def view_template(&block)
      label(for: @id, **@label_attrs) do
        input(**input_attributes)
        yield if block
      end
    end

    private

    def input_attributes
      { type: :checkbox, name: @name, id: @id, value: @value,
        checked: @checked, **@input_attrs }
    end
  end
end
