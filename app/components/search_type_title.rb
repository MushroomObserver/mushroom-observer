# frozen_string_literal: true

# Faceted-search page title: "Search <Type>", where `<Type>` is a
# bolded dropdown toggle listing the other models with a faceted
# search form (`Views::Layouts::TopNav::SEARCH_FORM_TYPES`). Picking
# one swaps `#search_nav_form` to that type's form via the same
# turbo-stream path the bar's type select already uses (see
# `search-type_controller.js#chooseType`); the `href` is a plain-GET
# fallback when JS is unavailable.
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
    TYPES.map do |type|
      [type.ti, { controller: "/#{type}/search", action: :new },
       { active: type == @current_type,
         data: { action: "search-type#chooseType", type: type.to_s } }]
    end
  end
end
