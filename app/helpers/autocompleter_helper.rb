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
    ac_args[:wrap_data] = autocompleter_wrap_data(args)
    ac_args[:label_after] = autocompleter_label_after(args)
    ac_args[:label_end] = autocompleter_label_end(args)
    ac_args[:append] = autocompleter_append(args)

    if args[:textarea] == true
      text_area_with_label(**ac_args)
    else
      text_field_with_label(**ac_args)
    end
  end

  # Any arg not on this list gets sent to the text field/area.
  def autocompleter_outer_args
    [:wrap_data, :type, :separator, :textarea, :hidden_value, :hidden_data,
     :create_text, :keep_text, :edit_text, :find_text, :create, :create_path,
     :map_outlet, :geocode_outlet]
  end

  def autocompleter_wrap_data(args)
    {
      controller: :autocompleter, type: args[:type],
      separator: args[:separator],
      autocompleter_map_outlet: args[:map_outlet],
      autocompleter_geocode_outlet: args[:geocode_outlet],
      autocompleter_target: "wrap"
    }.deep_merge(args[:wrap_data] || {})
  end

  def autocompleter_label_after(args)
    capture do
      [
        autocompleter_has_id_indicator,
        autocompleter_find_button(args),
        autocompleter_keep_button(args),
        autocompleter_hidden_field(**args)
      ].safe_join
    end
  end

  def autocompleter_label_end(args)
    capture do
      concat(autocompleter_create_button(args))
      concat(autocompleter_modal_create_link(args))
    end
  end

  def autocompleter_append(args)
    capture do
      concat(autocompleter_dropdown)
      concat(args[:append])
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
      icon: :plus, show_text: true, icon_class: "text-primary",
      name: "create_#{args[:type]}", class: "ml-3 create-button",
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
      name: "find_#{args[:type]}", class: "ml-3 d-none",
      data: { map_target: "showBoxBtn",
              action: "map#showBox:prevent" }
    )
  end

  def autocompleter_keep_button(args)
    return unless args[:keep_text]

    icon_link_to(
      args[:keep_text], "#",
      icon: :apply, show_text: false, icon_class: "text-primary",
      active_icon: :edit, active_content: args[:edit_text],
      name: "keep_#{args[:type]}", class: "ml-3 d-none",
      data: { autocompleter_target: "keepBtn", map_target: "lockBoxBtn",
              action: "map#toggleBoxLock:prevent" }
    )
  end

  # minimum args :form, :type.
  # Send :hidden to fill the id, :hidden_data to merge with hidden field data
  def autocompleter_hidden_field(**args)
    return unless args[:form].present? && args[:type].present?

    model = autocompleter_type_to_model(args[:type])
    data = { autocompleter_target: "hidden" }.merge(args[:hidden_data] || {})
    args[:form].hidden_field(:"#{model}_id", value: args[:hidden_value], data:)
  end

  def autocompleter_type_to_model(type)
    case type
    when :region
      :location
    when :clade
      :name
    else
      type
    end
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
