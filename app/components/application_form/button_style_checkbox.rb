# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Two independent click zones: a fixed-width checkbox zone (BS4
  # custom-checkbox graphic) and a flex-grow label zone (block
  # content). Fixes touch precision on a single wrapping `<label>`.
  #
  # `label_wrap: true` also wraps the label zone in a `<label
  # for=id>`, for content with no competing click action (e.g.
  # Form::UploadGallery::Item's thumbnail picker).
  #
  # @example
  #   render(Components::ApplicationForm::ButtonStyleCheckbox.new(
  #     name: "q[types][]", value: "observation",
  #     id: "type_observation", checked: types.include?("observation"),
  #     variant: :outline, size: :sm,
  #     label: { class: "filter-checkbox" }
  #   )) do
  #     plain "Observations"
  #   end
  class ButtonStyleCheckbox < Phlex::HTML
    include ::Components

    # @param name [String] HTML name (shared across checkboxes in a group)
    # @param value [String] value submitted when this checkbox is checked
    # @param id [String] HTML id (matches the checkbox zone's label `for`)
    # @param checked [Boolean] initial checked state
    # @param variant [Symbol, nil] btn variant for the outer wrapper
    # @param size [Symbol, nil] btn size modifier for the outer wrapper
    # @param label_wrap [Boolean] also wrap the label zone in a
    #   `<label for=id>` (default false)
    # @param label [Hash] extra HTML attrs for the outer wrapper
    # @param input_attrs [Hash] HTML attrs passed through to `<input>`
    def initialize(name:, value:, id:, **opts)
      super()
      @name = name
      @value = value
      @id = id
      @checked = opts.delete(:checked) { false }
      @variant = opts.delete(:variant)
      @size = opts.delete(:size)
      @label_wrap = opts.delete(:label_wrap) { false }
      @wrapper_attrs = opts.delete(:label) || {}
      @input_attrs = opts
    end

    def view_template(&block)
      Button(tag: :span, variant: @variant, size: @size,
             **mix({ class: "d-flex align-items-center" }, @wrapper_attrs)) do
        render_checkbox_zone
        render_label_zone(&block)
      end
    end

    private

    def render_checkbox_zone
      div(class: "custom-control custom-checkbox checkbox-zone") do
        input(**input_attributes)
        label(class: "custom-control-label", for: @id)
      end
    end

    def render_label_zone(&block)
      if @label_wrap
        label(for: @id, class: "label-zone flex-grow-1") { yield if block }
      else
        div(class: "label-zone flex-grow-1") { yield if block }
      end
    end

    def input_attributes
      mix({ type: :checkbox, name: @name, id: @id, value: @value,
            checked: @checked, class: "custom-control-input" },
          @input_attrs)
    end
  end
end
