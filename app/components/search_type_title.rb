# frozen_string_literal: true

# Faceted-search page title: "Search <Type>", a bolded dropdown
# listing the other models with a faceted search form. Picking one
# swaps `#search_nav_form` via the same turbo-stream path the bar's
# type select uses (see `search-type_controller.js#chooseType`).
class Components::SearchTypeTitle < Components::Base
  prop :current_type, ::Symbol

  TYPES = ::Views::Layouts::TopNav::SEARCH_FORM_TYPES

  def view_template
    plain(:search.ti)
    whitespace
    Dropdown(
      id: "search_type_toggle",
      menu_id: "search_type_menu",
      label: @current_type.ti,
      toggle_content: capture { strong { plain(@current_type.ti) } },
      toggle_class: "px-0",
      element: :span
    ) do |menu|
      menu.section(type_tuples)
    end
  end

  private

  def type_tuples
    TYPES.map { |type| type_tuple(type) }.sort_by(&:first)
  end

  def type_tuple(type)
    active = type == @current_type
    args = { active: active }
    args[:data] = { action: "search-type#chooseType", type: type.to_s } \
      unless active
    [type.ti, { controller: "/#{type}/search", action: :new }, args]
  end
end
