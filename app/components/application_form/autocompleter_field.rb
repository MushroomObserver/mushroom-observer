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

    # Types with dedicated Stimulus controllers
    SUPPORTED_TYPE_CONTROLLERS = [
      :name, :user, :location, :herbarium, :project, :species_list,
      :clade, :region
    ].freeze

    attr_reader :wrapper_options, :autocompleter_type, :textarea,
                :find_text, :keep_text, :edit_text, :create_text,
                :create, :create_path, :hidden_name, :hidden_value,
                :hidden_data, :extra_controller_data

    def initialize(field, type:, textarea: false, **options)
      super(field, attributes: {})
      @autocompleter_type = type
      @textarea = textarea
      extract_options(options)
    end

    def extract_options(options)
      @field_attributes = options.fetch(:attributes, {})
      @wrapper_options = options.fetch(:wrapper_options, {})
      @find_text = options[:find_text]
      @keep_text = options[:keep_text]
      @edit_text = options[:edit_text]
      @create_text = options[:create_text]
      @create = options[:create]
      @create_path = options[:create_path]
      @hidden_name = options[:hidden_name]
      @hidden_value = options[:hidden_value]
      @hidden_data = options[:hidden_data]
      @extra_controller_data = options[:controller_data] || {}
    end

    # Override superclass method to use our @field_attributes
    def attributes
      @field_attributes
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
      data = {
        controller: stimulus_controller_name,
        type: autocompleter_type
      }
      # Textarea autocompleters accept multiple values separated by newlines
      data[:separator] = "\n" if textarea
      data.merge(extra_controller_data)
    end

    # Returns the Stimulus controller name for this autocompleter type.
    # Type-specific controllers use naming convention: autocompleter--{type}
    def stimulus_controller_name
      unless type_specific_controller_exists?
        Rails.logger.warn("Unknown autocompleter type: #{autocompleter_type}")
      end
      :"autocompleter--#{autocompleter_type}"
    end

    def type_specific_controller_exists?
      SUPPORTED_TYPE_CONTROLLERS.include?(autocompleter_type.to_sym)
    end

    # Returns the Stimulus target attribute key for this autocompleter type.
    # For namespaced controllers like autocompleter--location, targets use
    # data-autocompleter--location-target (autocompleter__location_target)
    def target_attr_key
      :"#{stimulus_controller_name.to_s.tr("-", "_")}_target"
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
        data: { target_attr_key => "input" }
      }.deep_merge(attributes)
    end

    def autocompleter_wrapper_options
      wrapper_options.merge(
        wrap_data: { target_attr_key => "wrap" },
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
    def render_label_after
      render_has_id_indicator
      render_find_button if find_text
      render_keep_box_button if keep_text
      render_edit_box_button if keep_text
    end

    # Renders all label_end elements (goes in label_end slot)
    def render_label_end
      render_create_button if create_text && create.blank?
      render_modal_create_link if create_text && create.present? &&
                                  create_path.present?
    end

    def render_has_id_indicator
      link_icon(
        :check,
        title: :autocompleter_has_id.l,
        class: "px-2 text-success has-id-indicator",
        data: { target_attr_key => "hasIdIndicator" }
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
        data: { target_attr_key => "keepBtn", map_target: "lockBoxBtn",
                action: "map#toggleBoxLock:prevent form-exif#showFields" }
      )
    end

    def render_edit_box_button
      return unless keep_text

      icon_link_to(
        edit_text, "#",
        icon: :edit, show_text: false, icon_class: "text-primary",
        name: "edit_#{autocompleter_type}", class: "ml-3 edit-btn d-none",
        data: { target_attr_key => "editBtn", map_target: "editBoxBtn",
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
        data: { target_attr_key => "createBtn",
                action: "#{stimulus_controller_name}#swapCreate:prevent" }
      )
    end

    def render_modal_create_link
      return unless create_text && create.present? && create_path.present?

      modal_link_to(
        create, create_text, create_path,
        icon: :plus, show_text: true, icon_class: "text-primary",
        name: "create_#{autocompleter_type}", class: "ml-3 create-link",
        data: { target_attr_key => "createBtn" }
      )
    end

    def render_dropdown
      div(
        class: "auto_complete dropdown-menu",
        data: {
          target_attr_key => "pulldown",
          action: "scroll->#{stimulus_controller_name}#scrollList:passive"
        }
      ) do
        ul(class: "virtual_list",
           data: { target_attr_key => "list" }) do
          10.times do |i|
            li(class: "dropdown-item") do
              link_to(
                "",
                "#",
                data: {
                  row: i,
                  action: "click->#{stimulus_controller_name}#selectRow:prevent"
                }
              )
            end
          end
        end
      end
    end

    def render_hidden_field
      input(
        type: "hidden",
        id: hidden_field_id,
        name: hidden_field_name,
        value: normalized_hidden_value,
        class: "form-control",
        readonly: true,
        data: hidden_field_data
      )
    end

    # Convert array of IDs to comma-separated string for multi-value fields
    def normalized_hidden_value
      return hidden_value unless hidden_value.is_a?(Array)

      hidden_value.join(",")
    end

    def hidden_field_data
      base_data = { target_attr_key => "hidden" }
      return base_data unless hidden_data

      base_data.merge(hidden_data)
    end

    # Hidden field stores the selected ID. Use field.key (original field name)
    # so controller gets e.g. by_users_id, not user_id.
    def hidden_field_id
      hidden_name || "#{field.dom.id}_id"
    end

    # If field key has brackets (e.g., "writein_name[1]"), convert to
    # underscores to avoid Rails param parsing conflicts.
    def hidden_field_name
      return hidden_name if hidden_name

      key = field.key.to_s.tr("[]", "_").chomp("_")
      field.dom.name.sub(/\[#{field.key}\]$/, "[#{key}_id]")
    end
  end
end
