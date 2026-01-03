# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap autocompleter input field component with dropdown suggestions
  # Wraps a text input with Stimulus autocompleter controller
  # rubocop:disable Metrics/ClassLength
  class AutocompleterField < Superform::Rails::Components::Input
    include Phlex::Slotable

    register_output_helper :link_icon
    register_output_helper :icon_link_to
    register_output_helper :modal_link_to

    # Types with dedicated Stimulus controllers
    SUPPORTED_TYPE_CONTROLLERS = [
      :name, :user, :location, :herbarium, :project, :species_list,
      :clade, :region
    ].freeze

    slot :append
    slot :between
    slot :help

    # Make slot accessor public (Phlex::Slotable makes them private by default)
    public :append_slot, :between_slot, :help_slot

    attr_reader :wrapper_options, :autocompleter_type, :textarea,
                :find_text, :keep_text, :edit_text, :create_text,
                :create, :create_path, :hidden_name, :hidden_value,
                :hidden_data, :extra_controller_data, :custom_controller_id,
                :map_outlet

    def initialize(field, type:, textarea: false, **options)
      super(field, attributes: {})
      @autocompleter_type = type
      @textarea = textarea
      extract_options(options)
    end

    def extract_options(options)
      extract_field_options(options)
      extract_button_options(options)
      extract_hidden_field_options(options)
    end

    def extract_field_options(options)
      @field_attributes = options.fetch(:attributes, {})
      @wrapper_options = options.fetch(:wrapper_options, {})
      @custom_controller_id = options[:controller_id]
      @map_outlet = options[:map_outlet]
      @extra_controller_data = options[:controller_data] || {}
    end

    def extract_button_options(options)
      @find_text = options[:find_text]
      @keep_text = options[:keep_text]
      @edit_text = options[:edit_text]
      @create_text = options[:create_text]
      @create = options[:create]
      @create_path = options[:create_path]
    end

    def extract_hidden_field_options(options)
      @hidden_name = options[:hidden_name]
      @hidden_value = options[:hidden_value]
      @hidden_data = options[:hidden_data]
    end

    # Override superclass method to use our @field_attributes
    def attributes
      @field_attributes
    end

    def view_template
      div(
        id: controller_id,
        class: "autocompleter",
        data: controller_data
      ) do
        render_input_field do
          render_dropdown
          render_hidden_field
        end
        # Render append slot content (e.g., map section)
        render(append_slot) if append_slot
      end
    end

    private

    def controller_id
      custom_controller_id || "#{field.dom.id}_autocompleter"
    end

    def controller_data
      data = {
        controller: stimulus_controller_name,
        type: autocompleter_type
      }
      # Textarea autocompleters accept multiple values separated by newlines
      data[:separator] = "\n" if textarea
      data.merge(outlet_data).merge(extra_controller_data)
    end

    def outlet_data
      return {} unless map_outlet

      prefix = stimulus_controller_name.to_s.tr("-", "_")
      { "#{prefix}_map_outlet": map_outlet }
    end

    # Returns the Stimulus controller name for this autocompleter type.
    # Type-specific controllers use naming convention: autocompleter--{type}
    # Stimulus normalizes underscores to hyphens, so we do the same here
    # to ensure data-action attributes match the normalized controller name.
    def stimulus_controller_name
      unless type_specific_controller_exists?
        Rails.logger.warn("Unknown autocompleter type: #{autocompleter_type}")
      end
      :"autocompleter--#{autocompleter_type.to_s.tr("_", "-")}"
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
        data: { target_attr_key => "input", autocompleter: true }
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
      # Also include user's custom between content if provided
      field_component.with_between do
        render(between_slot) if between_slot
        render_label_after
      end

      # Add label_end buttons to label_end slot
      field_component.with_label_end { render_label_end }

      # Pass through help slot to inner field
      field_component.with_help { render(help_slot) } if help_slot

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

    # Hidden field stores selected ID. Uses model prefix + hidden_name
    # if provided, otherwise field's dom.id + "_id".
    def hidden_field_id
      return "#{field.dom.id}_id" unless hidden_name

      "#{model_prefix}_#{hidden_name}"
    end

    # Strips field key suffix from dom.id to get model prefix
    # e.g., "herbarium_place_name" -> "herbarium"
    def model_prefix
      field.dom.id.to_s.sub(/_#{field.key}$/, "")
    end

    # Converts brackets in field key to underscores for param parsing.
    def hidden_field_name
      return custom_hidden_field_name if hidden_name

      default_hidden_field_name
    end

    def custom_hidden_field_name
      "#{model_namespace}[#{hidden_name}]"
    end

    # Strips field key suffix from dom.name to get model namespace
    # e.g., "herbarium[place_name]" -> "herbarium"
    def model_namespace
      field.dom.name.to_s.sub(/\[#{field.key}\]$/, "")
    end

    def default_hidden_field_name
      key = field.key.to_s.tr("[]", "_").chomp("_")
      field.dom.name.sub(/\[#{field.key}\]$/, "[#{key}_id]")
    end
    # rubocop:enable Metrics/ClassLength
  end
end
