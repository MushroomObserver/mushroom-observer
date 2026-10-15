# frozen_string_literal: true

# The collapsible search-bar row -- a sibling of `TopNav`, rendered
# directly below it (`Views::Layouts::Application#render_right_side`).
# Holds either `SearchBar` (the pattern-search form + type select) or,
# on identify pages, `FormFilter`. Toggled open/closed by the
# magnifying-glass button `TopNav` renders (`target_id: "search_nav"`
# -- an id reference, so it works regardless of where `#search_nav`
# physically renders).
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
    # `flex: false` -- see `Components::Navbar`. `border-top-0` keeps
    # this element's border from doubling up with #top_nav's bottom
    # border sitting above it.
    Navbar(variant: :default, element: :div, flex: false, id: "search_nav",
           class: class_names("border-top-0", "hidden-print",
                              collapse_classes),
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
    Components::Collapsible.collapse_classes
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
