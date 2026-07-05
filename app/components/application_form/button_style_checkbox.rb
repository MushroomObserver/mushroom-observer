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
  #     variant: :outline, size: :sm,
  #     label: { class: "filter-checkbox" }
  #   )) do
  #     plain "Observations"
  #   end
  class ButtonStyleCheckbox < Phlex::HTML
    # Extends `Phlex::HTML` directly (not `Components::Base`), so it
    # gets no Kit sugar on its own — see `.claude/rules/phlex_reference.md`'s
    # "Kit sugar doesn't reach app/components/application_form/*" section.
    include ::Components

    # @param name [String] HTML name (shared across checkboxes in a group)
    # @param value [String] value submitted when this checkbox is checked
    # @param id [String] HTML id (matches the label's `for`)
    # @param checked [Boolean] initial checked state
    # @param variant [Symbol, nil] btn variant; nil for btn-default,
    #   :strip for a plain label with no btn classes
    # @param size [Symbol, nil] btn size modifier (`:sm`, `:lg`, etc.)
    # @param label [Hash] extra HTML attrs for the `<label>` (e.g.
    #   `class:` for identifier classes, `data:`). Do not pass btn
    #   classes here — use `variant:` and `size:` instead.
    # @param input_attrs [Hash] HTML attrs passed through to `<input>`
    def initialize(name:, value:, id:, **opts)
      super()
      @name = name
      @value = value
      @id = id
      @checked = opts.delete(:checked) { false }
      @variant = opts.delete(:variant)
      @size = opts.delete(:size)
      @label_attrs = opts.delete(:label) || {}
      @input_attrs = opts
    end

    def view_template(&block)
      Button(tag: :label, for: @id, variant: @variant, size: @size,
             **@label_attrs) do
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
