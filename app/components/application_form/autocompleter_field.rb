# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap autocompleter input field component with dropdown suggestions
  # Wraps a text input with Stimulus autocompleter controller
  class AutocompleterField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Slotable
    include FieldWithHelp

    slot :between
    slot :append

    attr_reader :wrapper_options, :autocompleter_type, :textarea

    def initialize(field, type:, textarea: false, attributes: {},
                   wrapper_options: {})
      super(field, attributes: attributes)
      @autocompleter_type = type
      @textarea = textarea
      @wrapper_options = wrapper_options
    end

    def view_template
      div(
        id: controller_id,
        class: "autocompleter",
        data: controller_data
      ) do
        render_with_wrapper do
          render_input_field
        end
        render_dropdown
        render_hidden_field
      end
    end

    private

    def controller_id
      "#{field.dom.id}_autocompleter"
    end

    def controller_data
      {
        controller: :autocompleter,
        type: autocompleter_type
      }
    end

    def render_input_field
      field_attributes = attributes.merge(
        class: class_names(attributes[:class], "dropdown"),
        placeholder: :start_typing.l,
        autocomplete: "off",
        data: { autocompleter_target: "input" }
      )

      if textarea
        render(field.textarea(**field_attributes))
      else
        render(field.text(**field_attributes))
      end
    end

    def render_dropdown
      div(
        class: "auto_complete dropdown-menu",
        data: {
          autocompleter_target: "pulldown",
          action: "scroll->autocompleter#scrollList:passive"
        }
      ) do
        ul(class: "virtual_list",
           data: { autocompleter_target: "list" }) do
          10.times do |i|
            li(class: "dropdown-item") do
              link_to(
                "",
                "#",
                data: {
                  row: i,
                  action: "click->autocompleter#selectRow:prevent"
                }
              )
            end
          end
        end
      end
    end

    def render_hidden_field
      # Hidden field stores the selected ID (e.g., herbarium_id)
      input(
        type: "hidden",
        id: "#{field.dom.id}_id",
        name: field.dom.name.sub(/\[#{field.key}\]$/,
                                 "[#{autocompleter_type}_id]"),
        class: "form-control",
        readonly: true,
        data: { autocompleter_target: "hidden" }
      )
    end

    def render_with_wrapper
      extract_wrapper_options => {
        show_label:, label_text:, inline:, wrap_class:
      }

      div(class: form_group_class("form-group", inline, wrap_class),
          data: { autocompleter_target: "wrap" }) do
        render_label_row(label_text, inline) if show_label
        yield
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def extract_wrapper_options
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      inline = wrapper_options[:inline] || false
      wrap_class = wrapper_options[:wrap_class]

      { show_label:, label_text:, inline:, wrap_class: }
    end

    def render_label_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"

      div(class: "#{display} justify-content-between") do
        div do
          label(for: field.dom.id, class: "mr-3") { label_text }
          render_help_in_label_row
          render(between_slot) if between_slot
        end
      end
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
