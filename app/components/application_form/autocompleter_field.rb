# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Text input with dropdown suggestions, backed by a Stimulus
  # autocompleter controller.
  # rubocop:disable Metrics/ClassLength
  class AutocompleterField < ::Components::Form::Input
    include Phlex::Slotable
    include FieldWithHelp # for render_help_icon

    # Types with dedicated Stimulus controllers
    SUPPORTED_TYPE_CONTROLLERS = [
      :name, :user, :location, :herbarium, :project, :user_project,
      :species_list, :clade, :region
    ].freeze

    slot :append
    slot :between
    slot :help
    # Caller-supplied content for the label row, after the built-in
    # has-id-indicator/find/keep buttons.
    slot :label_append

    # Make slot accessor public (Phlex::Slotable makes them private by default)
    public :append_slot, :between_slot, :help_slot, :label_append_slot

    attr_reader :wrapper_options, :autocompleter_type, :textarea,
                :find_text, :keep_text, :edit_text, :create_text,
                :create, :create_path, :hidden_name, :hidden_value,
                :hidden_data, :extra_controller_data, :extra_data,
                :custom_controller_id, :map_outlet

    def initialize(field, type:, textarea: false, **options)
      super(field)
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
      @extra_data = options[:data] || {}
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

    def attributes
      @field_attributes
    end

    def view_template
      div(
        id: controller_id,
        class: class_names("autocompleter", wrapper_options[:wrap_class]),
        data: controller_data
      ) do
        render_input_field do
          render_dropdown
          render_hidden_field
          render_has_id_indicator if inline?
        end
        render(append_slot) if append_slot
      end
    end

    private

    # Only set when the caller passes controller_id: (e.g. map outlets).
    def controller_id
      custom_controller_id
    end

    def inline?
      wrapper_options[:inline] || false
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

    # Stimulus normalizes underscores to hyphens in controller names.
    def stimulus_controller_name
      unless type_specific_controller_exists?
        Rails.logger.warn("Unknown autocompleter type: #{autocompleter_type}")
      end
      :"autocompleter--#{autocompleter_type.to_s.tr("_", "-")}"
    end

    def type_specific_controller_exists?
      SUPPORTED_TYPE_CONTROLLERS.include?(autocompleter_type.to_sym)
    end

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

    # `mix` concatenates String values, so a caller's placeholder: is
    # omitted from defaults rather than merged with ours.
    def autocompleter_field_attributes
      defaults = { autocomplete: "off", data: input_data_attributes }
      unless attributes.key?(:placeholder)
        defaults[:placeholder] =
          :start_typing.l
      end
      mix(defaults, attributes)
    end

    def input_data_attributes
      # String "true", not boolean -- avoids Phlex's boolean shorthand.
      { target_attr_key => "input", autocompleter: "true" }.merge(extra_data)
    end

    def autocompleter_wrapper_options
      wrapper_options.merge(
        wrap_data: { target_attr_key => "wrap" },
        wrap_class: class_names(wrapper_options[:wrap_class], "dropdown"),
        wrap_append_in_input_group: true,
        help_icon_in_label_row: inline?,
        **addon_wrapper_options
      )
    end

    # label: false has no label row, so route the same buttons into
    # the input-group-addon instead.
    def addon_wrapper_options
      return {} if wrapper_options[:label] != false

      { addon: capture { render_label_after } }
    end

    def add_slots_to_field(field_component, &block)
      add_label_appends_slot(field_component)

      # Only wire up label_end when there's content -- an empty slot
      # still forces the d-flex layout with an empty right side.
      if create_text || help_icon_in_label_end?
        field_component.with_label_end { render_label_end }
      end

      field_component.with_between { render(between_slot) } if between_slot
      field_component.with_help { render(help_slot) } if help_slot
      field_component.with_append(&block) if block
    end

    def add_label_appends_slot(field_component)
      return if wrapper_options[:label] == false
      return if inline? && !find_text && !keep_text

      field_component.with_label_appends { render_label_after }
    end

    def render_label_after
      render_has_id_indicator unless inline?
      render_find_button if find_text
      render_keep_edit_toggle if keep_text
      render(label_append_slot) if label_append_slot
    end

    # Help trigger comes last, after the create button.
    def render_label_end
      render_create_button if create_text && create.blank?
      render_modal_create_link if create_text && create.present? &&
                                  create_path.present?
      render_help_icon if help_icon_in_label_end?
    end

    def help_icon_in_label_end?
      !inline? && help_slot && wrapper_options[:help_collapse]
    end

    # `invisible`, not `d-none` -- keeps the box in layout so later
    # content doesn't shift when the checkmark toggles.
    def render_has_id_indicator
      title = :autocompleter_has_id.l
      span(class: class_names(FieldLabelRow::GAP_LEADING,
                              "has-id-indicator invisible inline-flex-center"),
           title: title,
           data: { target_attr_key => "hasIdIndicator",
                   tooltip_target: "tip", placement: "top" }) do
        Icon(type: :check, class: "text-success")
      end
    end

    # Plain Buttons, not Links -- client-side toggles with no
    # destination, each building the tooltip data by hand.
    def render_find_button
      return unless find_text

      Button(name: find_text,
             icon: :find_on_map, show_label: :hidden,
             icon_class: "text-primary",
             variant: :link,
             class: class_names(FieldLabelRow::GAP_LEADING,
                                "find-btn d-none p-0"),
             title: find_text,
             data: { map_target: "showBoxBtn",
                     action: "map#showBox",
                     tooltip_target: "tip", placement: "top",
                     title: find_text })
    end

    # One button, two appearances -- CSS swaps icon/tooltip off the
    # `.active` class map#toggleBoxLock toggles (_icons.scss).
    def render_keep_edit_toggle
      return unless keep_text

      Button(name: keep_text,
             icon: :apply, active_icon: :edit, active_content: edit_text,
             show_label: :hidden,
             icon_class: "text-primary",
             variant: :link,
             class: class_names(FieldLabelRow::GAP_LEADING,
                                "keep-edit-toggle d-none p-0"),
             title: keep_text,
             data: { target_attr_key => "keepOrEditBtn",
                     map_target: "boxLockToggle",
                     action: "map#toggleBoxLock " \
                             "form-exif#showFields",
                     tooltip_target: "tip", placement: "top",
                     active_title: edit_text,
                     title: keep_text })
    end

    def render_create_button
      return if !create_text || create.present?

      Button(name: create_text,
             id: "create_#{autocompleter_type}_btn",
             class: class_names(FieldLabelRow::GAP_LEADING,
                                "create-button d-none p-0"),
             icon: :plus, show_label: :responsive,
             icon_class: "text-primary",
             variant: :link,
             title: create_text,
             data: { target_attr_key => "createBtn",
                     action: "#{stimulus_controller_name}#swapCreate",
                     tooltip_target: "tip", placement: "top",
                     title: create_text })
    end

    # Stays visible once rendered -- uses a separate target, not
    # createBtn, which base_controller.js toggles d-none on.
    def render_modal_create_link
      return unless create_text && create.present? && create_path.present?

      Link(type: :modal,
           modal_id: create,
           name: create_text,
           target: create_path,
           icon: :plus, show_label: :responsive,
           icon_class: "text-primary",
           class: class_names(FieldLabelRow::GAP_LEADING, "create-link"),
           data: { target_attr_key => "createLink" })
    end

    def render_dropdown
      div(
        class: "auto_complete dropdown-menu",
        data: {
          target_attr_key => "pulldown",
          action: "scroll->#{stimulus_controller_name}#scrollList:passive"
        }
      ) do
        div(class: "virtual_list",
            data: { target_attr_key => "list" }) do
          10.times do |i|
            Link(
              type: :get,
              name: "",
              target: "#",
              class: "dropdown-item",
              data: {
                row: i,
                action: "click->#{stimulus_controller_name}#selectRow:prevent"
              }
            )
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
        readonly: "readonly",
        autocomplete: "off",
        data: hidden_field_data
      )
    end

    def normalized_hidden_value
      return hidden_value unless hidden_value.is_a?(Array)

      hidden_value.join(",")
    end

    def hidden_field_data
      base_data = { target_attr_key => "hidden" }
      return base_data unless hidden_data

      base_data.merge(hidden_data)
    end

    def hidden_field_id
      return "#{field.dom.id}_id" unless hidden_name

      "#{model_prefix}_#{hidden_name}"
    end

    # Splits dom.name on the last [...] group, e.g.
    # "species_list[place_name]" -> ["species_list", "place_name"].
    def name_parts
      @name_parts ||= begin
                        name = field.dom.name.to_s
                        match = name.match(/\A(.*)\[([^\[\]]+)\]\z/)
                        match ? [match[1], match[2]] : ["", name]
                      end
    end

    def model_namespace
      name_parts[0]
    end

    def leaf_key
      name_parts[1]
    end

    # "member[notes]" -> "member_notes" (a valid HTML id segment).
    def model_prefix
      model_namespace.tr("[]", "_").gsub(/__+/, "_").chomp("_")
    end

    def hidden_field_name
      return custom_hidden_field_name if hidden_name

      default_hidden_field_name
    end

    def custom_hidden_field_name
      # No namespace = standalone FieldProxy usage outside a form.
      return hidden_name.to_s if model_namespace.empty?

      "#{model_namespace}[#{hidden_name}]"
    end

    def default_hidden_field_name
      return "#{leaf_key}_id" if model_namespace.empty?

      "#{model_namespace}[#{leaf_key}_id]"
    end
    # rubocop:enable Metrics/ClassLength
  end
end
