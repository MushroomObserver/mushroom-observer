# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap autocompleter input field component with dropdown suggestions
  # Wraps a text input with Stimulus autocompleter controller
  # rubocop:disable Metrics/ClassLength
  # Inherits from `Components::Form::Input` (MO's thin subclass of
  # `Superform::Rails::Components::Input`).
  class AutocompleterField < ::Components::Form::Input
    include Phlex::Slotable

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

    # Only emit an outer-wrap id when the caller explicitly passes one.
    # Forms that need a stable CSS-selector handle (e.g. map outlets)
    # pass `controller_id:`; forms that don't shouldn't get noise.
    def controller_id
      custom_controller_id
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
      mix({ placeholder: :start_typing.l,
            autocomplete: "off",
            data: input_data_attributes },
          attributes)
    end

    def input_data_attributes
      # Use string "true" (not boolean true) so Phlex emits
      # `data-autocompleter="true"` instead of the boolean shorthand
      # `data-autocompleter`. autocompleter base_controller overwrites
      # this to `"connected"` on connect regardless.
      { target_attr_key => "input", autocompleter: "true" }.merge(extra_data)
    end

    def autocompleter_wrapper_options
      wrapper_options.merge(
        wrap_data: { target_attr_key => "wrap" },
        wrap_class: class_names(wrapper_options[:wrap_class], "dropdown")
      )
    end

    def add_slots_to_field(field_component, &block)
      # has-id-indicator + find/keep/edit buttons sit inline with the
      # label, inside the label row's flex container.
      field_component.with_label_appends { render_label_after }

      # Add label_end buttons to label_end slot — only when content is
      # present. Registering an empty slot makes `label_end_present?`
      # return true and forces the label row into the d-flex path
      # with an empty right side (see FieldLabelRow#render_label_row).
      field_component.with_label_end { render_label_end } if create_text

      # The caller's between content (block, between label row and
      # field) passes straight through.
      field_component.with_between { render(between_slot) } if between_slot

      # Pass through help slot to inner field
      field_component.with_help { render(help_slot) } if help_slot

      # Add dropdown and hidden field to append slot
      field_component.with_append(&block) if block
    end

    # Renders all label_after elements (goes in between slot after label)
    def render_label_after
      render_has_id_indicator
      render_find_button if find_text
      render_keep_edit_toggle if keep_text
    end

    # Renders all label_end elements (goes in label_end slot)
    def render_label_end
      render_create_button if create_text && create.blank?
      render_modal_create_link if create_text && create.present? &&
                                  create_path.present?
    end

    # A bare <svg> can't take padding -- shrinks the checkmark instead
    # of adding space. Spacing and the show/hide toggle
    # (_autocomplete.scss) live on this wrapping span instead; the
    # tooltip lives here too since `title:` on Icon alone doesn't
    # work on a bare svg.
    def render_has_id_indicator
      title = :autocompleter_has_id.l
      span(class: "ml-3 has-id-indicator d-none inline-flex-center",
           title: title,
           data: { target_attr_key => "hasIdIndicator",
                   tooltip_target: "tip", placement: "top" }) do
        Icon(type: :check, class: "text-success")
      end
    end

    # Plain `Button`s, not `Link`s -- client-side toggles with no
    # destination. `variant: :link, class: "... p-0"` gives Bootstrap's
    # `.btn-link` reset with zero padding. `Link::Get` auto-wires a
    # tooltip from `icon:`; plain `Button` doesn't, so each one below
    # builds the same tooltip_data by hand.
    def render_find_button
      return unless find_text

      Button(name: find_text,
             icon: :find_on_map, show_label: :hidden,
             icon_class: "text-primary",
             variant: :link,
             class: "ml-3 find-btn d-none p-0",
             title: find_text,
             data: { map_target: "showBoxBtn",
                     action: "map#showBox",
                     tooltip_target: "tip", placement: "top",
                     title: find_text })
    end

    # CSS swaps the icon off the `.active` class map#toggleBoxLock
    # sets on this element (`_icons.scss`'s `.stateful-link` rule).
    # `active_title:` swaps the tooltip the same way -- `Link::Get`
    # wires that from `active_content:` automatically; plain `Button`
    # doesn't, so it's passed by hand (see `render_find_button`).
    def render_keep_edit_toggle
      return unless keep_text

      Button(name: keep_text,
             icon: :apply, active_icon: :edit, active_content: edit_text,
             show_label: :hidden,
             icon_class: "text-primary",
             variant: :link,
             class: "ml-3 keep-edit-toggle d-none p-0",
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
             class: "ml-3 create-button d-none p-0",
             icon: :plus, show_label: :responsive,
             icon_class: "text-primary",
             variant: :link,
             title: create_text,
             data: { target_attr_key => "createBtn",
                     action: "#{stimulus_controller_name}#swapCreate",
                     tooltip_target: "tip", placement: "top",
                     title: create_text })
    end

    # Unlike render_create_button, this link isn't has-id/offer-create
    # gated -- it stays visible once rendered, so it needs a separate
    # target, not createBtn (cssHasIdOrNo and the matches-based
    # debounce in base_controller.js both toggle createBtnTarget's
    # d-none, which would otherwise hide this on a blank/no-match form).
    def render_modal_create_link
      return unless create_text && create.present? && create_path.present?

      Link(type: :modal,
           modal_id: create,
           name: create_text,
           target: create_path,
           icon: :plus, show_label: :responsive,
           icon_class: "text-primary",
           class: "ml-3 create-link",
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

    # Model prefix + leaf key from the field's `dom.name`, split on
    # the LAST `[…]` group -- works whether `field.key` is a Symbol
    # (leaf only) or a String with the namespaced name already in it.
    # E.g. "member[notes][Cap]" -> ["member[notes]", "Cap"];
    # "approved_rank" (no brackets) -> ["", "approved_rank"].
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

    # Strips bracket characters and collapses runs to single underscores
    # so the prefix is a valid HTML id segment. `model_namespace` of
    # `"member[notes]"` becomes `"member_notes"`.
    def model_prefix
      model_namespace.tr("[]", "_").gsub(/__+/, "_").chomp("_")
    end

    def hidden_field_name
      return custom_hidden_field_name if hidden_name

      default_hidden_field_name
    end

    def custom_hidden_field_name
      # No model namespace = standalone usage via
      # `FieldProxy.new(nil, …)` outside a Superform form. The
      # hidden field gets the bare top-level `name="#{hidden_name}"`
      # instead of `"[hidden_name]"`.
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
