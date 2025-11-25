# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap autocompleter input field component with dropdown suggestions
  # Wraps a text input with Stimulus autocompleter controller
  class AutocompleterField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Rails::Helpers::LinkTo

    register_output_helper :link_icon
    register_output_helper :icon_link_to
    register_output_helper :modal_link_to

    attr_reader :wrapper_options, :autocompleter_type, :textarea,
                :find_text, :keep_text, :edit_text, :create_text,
                :create, :create_path

    def initialize(field, type:, textarea: false, **options)
      super(field, attributes: options.fetch(:attributes, {}))
      @autocompleter_type = type
      @textarea = textarea
      @wrapper_options = options.fetch(:wrapper_options, {})
      @find_text = options[:find_text]
      @keep_text = options[:keep_text]
      @edit_text = options[:edit_text]
      @create_text = options[:create_text]
      @create = options[:create]
      @create_path = options[:create_path]
    end

    def view_template(&block)
      div(
        id: controller_id,
        class: "autocompleter",
        data: controller_data
      ) do
        render_input_field do
          render_dropdown
          render_hidden_field
        end
        # Yield block for additional content (e.g., conditional collapse fields)
        yield if block
      end
    end

    private

    def controller_id
      "#{field.dom.id}_autocompleter"
    end

    def controller_data
      {
        controller: :autocompleter,
        # Use string to prevent underscore-to-hyphen conversion in data attrs
        type: autocompleter_type.to_s
      }
    end

    def render_input_field(&block)
      field_component = create_field_component
      add_slots_to_field(field_component, &block)
      render(field_component)
    end

    def create_field_component
      field_attributes = autocompleter_field_attributes
      field_wrapper_options = autocompleter_wrapper_options

      if textarea
        field.textarea(**field_attributes,
                       wrapper_options: field_wrapper_options)
      else
        field.text(**field_attributes, wrapper_options: field_wrapper_options)
      end
    end

    def autocompleter_field_attributes
      {
        placeholder: :start_typing.l,
        autocomplete: "off",
        data: { autocompleter_target: "input" }
      }.deep_merge(attributes)
    end

    def autocompleter_wrapper_options
      wrapper_options.merge(
        wrap_data: { autocompleter_target: "wrap" },
        wrap_class: class_names(wrapper_options[:wrap_class], "dropdown")
      )
    end

    def add_slots_to_field(field_component, &block)
      # Add label_after buttons to between slot (after label)
      field_component.with_between { render_label_after }

      # Add label_end buttons to label_end slot
      field_component.with_label_end { render_label_end }

      # Add dropdown and hidden field to append slot
      field_component.with_append(&block) if block
    end

    # Renders all label_after elements (goes in between slot after label)
    # rubocop:disable Rails/OutputSafety
    def render_label_after
      raw(render_has_id_indicator)
      raw(render_find_button) if find_text
      raw(render_keep_box_button) if keep_text
      raw(render_edit_box_button) if keep_text
    end

    # Renders all label_end elements (goes in label_end slot)
    def render_label_end
      raw(render_create_button) if create_text && create.blank?
      raw(render_modal_create_link) if create_text && create.present? &&
                                       create_path.present?
    end
    # rubocop:enable Rails/OutputSafety

    def render_has_id_indicator
      link_icon(
        :check,
        title: :autocompleter_has_id.l,
        class: "px-2 text-success has-id-indicator",
        data: { autocompleter_target: "hasIdIndicator" }
      )
    end

    def render_find_button
      return unless find_text

      icon_link_to(
        find_text, "#",
        icon: :find_on_map, show_text: false, icon_class: "text-primary",
        name: "find_#{autocompleter_type}", class: "ml-3 find-btn d-none",
        data: { map_target: "showBoxBtn",
                action: "map#showBox:prevent" }
      )
    end

    def render_keep_box_button
      return unless keep_text

      icon_link_to(
        keep_text, "#",
        icon: :apply, show_text: false, icon_class: "text-primary",
        name: "keep_#{autocompleter_type}", class: "ml-3 keep-btn d-none",
        data: { autocompleter_target: "keepBtn", map_target: "lockBoxBtn",
                action: "map#toggleBoxLock:prevent form-exif#showFields" }
      )
    end

    def render_edit_box_button
      return unless keep_text

      icon_link_to(
        edit_text, "#",
        icon: :edit, show_text: false, icon_class: "text-primary",
        name: "edit_#{autocompleter_type}", class: "ml-3 edit-btn d-none",
        data: { autocompleter_target: "editBtn", map_target: "editBoxBtn",
                action: "map#toggleBoxLock:prevent form-exif#showFields" }
      )
    end

    def render_create_button
      return if !create_text || create.present?

      icon_link_to(
        create_text, "#",
        id: "create_#{autocompleter_type}_btn", class: "ml-3 create-button",
        icon: :plus, show_text: true, icon_class: "text-primary",
        name: "create_#{autocompleter_type}",
        data: { autocompleter_target: "createBtn",
                action: "autocompleter#swapCreate:prevent" }
      )
    end

    def render_modal_create_link
      return unless create_text && create.present? && create_path.present?

      modal_link_to(
        create, create_text, create_path,
        icon: :plus, show_text: true, icon_class: "text-primary",
        name: "create_#{autocompleter_type}", class: "ml-3 create-link",
        data: { autocompleter_target: "createBtn" }
      )
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
  end
end
