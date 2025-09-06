# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
module AutocompleterHelper
  # MO's autocompleter_field is a text_field that fetches suggestions from the
  # db for the requested model. (For a textarea, pass textarea: true.)
  #
  # The stimulus controller handles keyboard and mouse interactions, does the
  # fetching, and draws the dropdown menu. `args` allow incoming data attributes
  # to deep_merge with controller data.
  #
  # We attempt to disable browser autocomplete via `autocomplete="off"` — the
  # W3C standard API, but it has never been honored by Chrome or Safari. Chrome
  # seems to be in a race to defeat the evolving hacks by developers to disable
  # inappropriate autocompletes, and Safari is not much better - you just can't
  # turn their crap off. (documented on SO)
  #
  def autocompleter_field(**args)
    ac_args = {
      placeholder: :start_typing.l, autocomplete: "off",
      data: { autocompleter_target: "input" }
    }.deep_merge(args.except(*autocompleter_outer_args))
    ac_args[:class] = class_names("dropdown", args[:class])
    # inner form-group wrap, because dropdown is position-absolute
    ac_args[:wrap_data] = { autocompleter_target: "wrap" }
    ac_args[:label_after] = autocompleter_label_after(args)
    ac_args[:label_end] = autocompleter_label_end(args)
    ac_args[:append] = autocompleter_append(args)

    tag.div(id: args[:controller_id], class: "autocompleter",
            data: autocompleter_controller_data(args)) do
      if args[:textarea] == true
        concat(text_area_with_label(**ac_args))
      else
        concat(text_field_with_label(**ac_args))
      end
      concat(args[:append])
    end
  end

  # Any arg not on this list gets sent to the text field/area.
  def autocompleter_outer_args
    [:controller_data, :controller_id, :type, :separator, :textarea,
     :hidden_value, :hidden_data, :create_text, :keep_text, :edit_text,
     :find_text, :create, :create_path, :map_outlet, :geocode_outlet].freeze
  end

  # This data goes on the outer div (controller element), not the input field.
  def autocompleter_controller_data(args)
    {
      controller: :autocompleter,
      type: args[:type],
      separator: args[:separator],
      autocompleter_map_outlet: args[:map_outlet],
      autocompleter_geocode_outlet: args[:geocode_outlet]
    }.deep_merge(args[:outer_data] || {})
  end

  def autocompleter_label_after(args)
    capture do
      [
        autocompleter_has_id_indicator,
        autocompleter_find_button(args),
        autocompleter_keep_box_button(args),
        autocompleter_edit_box_button(args)
      ].safe_join
    end
  end

  def autocompleter_label_end(args)
    capture do
      concat(autocompleter_create_button(args))
      concat(autocompleter_modal_create_link(args))
    end
  end

  def autocompleter_has_id_indicator
    link_icon(:check, title: :autocompleter_has_id.l,
                      class: "ml-3 px-2 text-success has-id-indicator",
                      data: { autocompleter_target: "hasIdIndicator" })
  end

  def autocompleter_create_button(args)
    return if !args[:create_text] || args[:create].present?

    icon_link_to(
      args[:create_text], "#",
      id: "create_#{args[:type]}_btn", class: "ml-3 create-button",
      icon: :plus, show_text: true, icon_class: "text-primary",
      name: "create_#{args[:type]}",
      data: { autocompleter_target: "createBtn",
              action: "autocompleter#swapCreate:prevent" }
    )
  end

  def autocompleter_modal_create_link(args)
    return unless args[:create_text] && args[:create].present? &&
                  args[:create_path].present?

    modal_link_to(
      args[:create], args[:create_text], args[:create_path],
      icon: :plus, show_text: true, icon_class: "text-primary",
      name: "create_#{args[:type]}", class: "ml-3 create-link",
      data: { autocompleter_target: "createBtn" }
    )
  end

  def autocompleter_find_button(args)
    return unless args[:find_text]

    icon_link_to(
      args[:find_text], "#",
      icon: :find_on_map, show_text: false, icon_class: "text-primary",
      name: "find_#{args[:type]}", class: "ml-3 find-btn d-none",
      data: { map_target: "showBoxBtn",
              action: "map#showBox:prevent" }
    )
  end

  def autocompleter_keep_box_button(args)
    return unless args[:keep_text]

    icon_link_to(
      args[:keep_text], "#",
      icon: :apply, show_text: false, icon_class: "text-primary",
      name: "keep_#{args[:type]}", class: "ml-3 keep-btn d-none",
      data: { autocompleter_target: "keepBtn", map_target: "lockBoxBtn",
              action: "map#toggleBoxLock:prevent form-exif#showFields" }
    )
  end

  def autocompleter_edit_box_button(args)
    return unless args[:keep_text]

    icon_link_to(
      args[:edit_text], "#",
      icon: :edit, show_text: false, icon_class: "text-primary",
      name: "edit_#{args[:type]}", class: "ml-3 edit-btn d-none",
      data: { autocompleter_target: "editBtn", map_target: "editBoxBtn",
              action: "map#toggleBoxLock:prevent form-exif#showFields" }
    )
  end

  # minimum args :form, :type. Send :hidden_name to override default field name,
  # :hidden_value to fill id, :hidden_data to merge with hidden field data
  def autocompleter_hidden_field(**args)
    return unless args[:form].present? && args[:field].present?

    # Default field name is "#{type}_id", so obs.place_name gets obs.location_id
    id = args[:hidden_name] || :"#{args[:type]}_id"
    data = { autocompleter_target: "hidden" }.merge(args[:hidden_data] || {})
    args[:form].hidden_field(
      id,
      value: args[:hidden_value], data:, class: "form-control", readonly: true
    )
  end

  def autocompleter_append(args)
    [autocompleter_dropdown,
     autocompleter_hidden_field(**args)].safe_join
  end

  def autocompleter_dropdown
    tag.div(class: "auto_complete dropdown-menu",
            data: { autocompleter_target: "pulldown",
                    action: "scroll->autocompleter#scrollList:passive" }) do
      tag.ul(class: "virtual_list", data: { autocompleter_target: "list" }) do
        10.times do |i|
          concat(tag.li(class: "dropdown-item") do
            link_to("", "#", data: {
                      row: i, action: "click->autocompleter#selectRow:prevent"
                    })
          end)
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
