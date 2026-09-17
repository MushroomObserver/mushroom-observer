# frozen_string_literal: true

# The collapsible search-bar row -- a sibling of `TopNav`, rendered
# directly below it (`Views::Layouts::Application#render_right_side`).
# Holds either `SearchBar` (the pattern-search form + type select) or,
# on identify pages, `FormFilter`. Toggled open/closed by the
# magnifying-glass button `TopNav` renders (`target_id: "search_nav"`
# -- an id reference, so it works regardless of where `#search_nav`
# physically renders).
#
# The navbar wrapper itself is the collapse target, not a div nested
# inside it -- a collapsed inner div still leaves the navbar's
# padding and border visible as an empty bar. Collapsing the whole
# navbar makes it disappear (`display: none`) entirely.
class Views::Layouts::SearchNav < Views::Base
  # Controllers / actions where the search-help dropdown is available.
  SEARCH_HELP_TYPES = [:names, :observations, :locations].freeze
  # Search types whose advanced-search form is reachable via the
  # form-toggle.
  SEARCH_FORM_TYPES = [
    :names, :observations, :locations,
    :projects, :herbaria, :species_lists
  ].freeze

  # Same rationale as `TopNav::CONTAINER_CLASSES` (`px-card` matches
  # card padding, so this row's content lines up with card content
  # below it) -- duplicated rather than shared, since the two navbars
  # are independent components now.
  CONTAINER_CLASSES = %w[container-fluid px-card w-100].freeze

  def view_template
    # `element: :div`, not the `Navbar` default `:nav` -- this is a
    # search toolbar, not a second navigation landmark (matches
    # `Sidebar`'s styling-only `Navbar` usage). `variant: :light`
    # still gets the full `.navbar-light` treatment (border, link
    # colors) from `mo/_top_nav.scss`, which is class-scoped, not
    # only `#top_nav`-scoped. `border-top-0` drops just the top
    # border, so it doesn't double up against `#top_nav`'s bottom
    # border sitting directly above it.
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
           }) do
      div(class: class_names(CONTAINER_CLASSES)) do
        render_search_row
      end
    end
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
