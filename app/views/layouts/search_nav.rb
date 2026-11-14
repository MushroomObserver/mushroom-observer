# frozen_string_literal: true

# The collapsible search-bar row -- a sibling of `TopNav`, rendered
# directly below it. Collapses as the navbar element itself, not a
# nested div, so its border/padding disappear with its content.
class Views::Layouts::SearchNav < Views::Base
  # Controllers / actions where the search-help dropdown is available.
  SEARCH_HELP_TYPES = [:names, :observations, :locations].freeze
  # Search types whose advanced-search form is reachable via the
  # form-toggle.
  SEARCH_FORM_TYPES = [
    :names, :observations, :locations,
    :projects, :herbaria, :species_lists
  ].freeze

  def view_template
    # `element: :div`, not the `Navbar` default `:nav` -- a search
    # toolbar, not a second navigation landmark.
    Navbar(variant: :light, element: :div,
           class: collapse_classes, id: "search_nav",
           padding: "py-2 px-0",
           data: {
             controller: "search-type",
             # Stimulus Array values must be JSON. Rails' tag helper
             # JSON-encodes arrays automatically; Phlex space-joins
             # them ("a b"), which breaks JSON.parse in the
             # controller and silently disables the help/advanced-
             # search forms (#4492).
             search_type_help_types_value: SEARCH_HELP_TYPES.to_json,
             search_type_form_types_value: SEARCH_FORM_TYPES.to_json
           }) { render_search_row }
  end

  private

  def collapse_classes
    Components::Collapsible.collapse_classes(
      html_class: "hidden-print mb-2 border-top-0"
    )
  end

  # Identify pages get a dedicated filter bar; everything else gets
  # the pattern-search bar.
  def render_search_row
    if controller.controller_name == "identify"
      render(::Views::Controllers::Observations::Identify::FormFilter.new)
    else
      render(Views::Layouts::SearchBar.new(
               search_help_types: SEARCH_HELP_TYPES,
               search_form_types: SEARCH_FORM_TYPES
             ))
    end
  end
end
