# frozen_string_literal: true

# The GET pattern-search form that lives in the top nav. Renders a
# `<form class="flex-bar … " action="/search/pattern" method="get">`
# wrapping a text input with the search-icon affordance and a type
# select, plus a submit button.
#
# Bound to a `FormObject::PatternSearch` so the submitted params
# land under `pattern_search[…]` — the shape
# `SearchController#pattern` reads.
#
# @example In the search-bar layout
#   render(Components::Form::PatternSearch.new(
#            FormObject::PatternSearch.new(
#              pattern: session[:pattern],
#              type: session[:search_type]
#            )
#          ))
class Components::Form::PatternSearch < Components::ApplicationForm
  # Pattern-searchable on the backend (SearchController::
  # PATTERN_SEARCHABLE_MODELS) but excluded from this dropdown:
  # Image.pattern's join is too expensive to expose on the
  # always-visible search bar. The backend stays working so the query
  # can be revisited later.
  DROPDOWN_EXCLUDED_TYPES = [:images].freeze

  # A few types show a label that differs from their model symbol.
  LABEL_OVERRIDES = { glossary_terms: :glossary }.freeze

  SEARCH_TYPE_OPTIONS = (
    (SearchController::PATTERN_SEARCHABLE_MODELS - DROPDOWN_EXCLUDED_TYPES).
      map { |type| [LABEL_OVERRIDES.fetch(type, type), type] } +
      [[:app_search_google, :google]]
  ).freeze

  # The selectable `type` values — the set a stored
  # `session[:search_type]` must belong to for the select to be able
  # to show it (see `Views::Layouts::SearchBar`).
  TYPE_VALUES = SEARCH_TYPE_OPTIONS.map(&:last).freeze

  # `.form-inline` gives this `<form>` flex behavior, but its default
  # flex-wrap: wrap lets the browser wrap the input group/select/
  # button onto separate lines rather than shrink them once they
  # don't fit -- flex-nowrap forces one row (paired with min-width: 0
  # on the shrinking children, see mo/_top_nav.scss). `flex-grow-1` on
  # the search field consumes all leftover main-axis space, so a
  # `justify-content` value has nothing left to distribute -- no
  # `.flex-bar` needed here. `Components::Navbar::FORM_CLASS` supplies
  # small padding/margin/border tweaks (_top_nav.scss, _layout.scss).
  FORM_CLASS = "flex-grow-1 form-inline flex-nowrap " \
               "#{Components::Navbar::FORM_CLASS} px-0 gap-2".freeze

  def initialize(model, **options)
    options[:id] ||= "pattern_search_form"
    options[:class] = [FORM_CLASS, options[:class]].flatten.compact.join(" ")
    # Match Rails `form_with`'s default `<form accept-charset="UTF-8">`.
    options[:"accept-charset"] ||= "UTF-8"
    super(model, method: :get, **options)
  end

  def form_action
    url_for(controller: "/search", action: :pattern, only_path: true)
  end

  def view_template
    # BS4 dropped BS3's `.has-feedback`/`.form-control-feedback`
    # icon-overlay pattern -- the documented replacement is an
    # `.input-group` with the icon in a prepended
    # `.input-group-text`, not an icon floated inside the input.
    # `.input-group` sets width: 100% unconditionally -- w-auto lifts
    # that so flex-sm-grow-1 (grow only at `sm`+) has room to share
    # the row with the select and submit button below `sm`.
    InputGroup(class: "flex-sm-grow-1 w-auto") do
      render(Components::InputGroup::Addon.new(
               variant: :addon, position: :prepend,
               class: Components::Column.mobile_hide_classes(display: :flex)
             )) { Icon(type: :search) }
      # `label: false` skips the form-group wrap + auto-label so the
      # input nests directly inside the navbar flex row, matching
      # the bare `<input>` Rails `f_s.text_field` emitted.
      text_field(:pattern, placeholder: :app_find.t,
                           label: false,
                           class: "form-control flex-grow-1")
    end
    render_type_select
    render_submit
  end

  private

  def render_type_select
    # `.form-control` sets width: 100% unconditionally -- width: :auto
    # shrinks the select to its content so it can share the row with
    # the input group and submit button below `sm`.
    select_field(:type, sorted_type_options,
                 label: false,
                 width: :auto,
                 class: "text-nowrap",
                 data: {
                   search_type_target: "select",
                   action: "search-type#getHelp search-type#getForm"
                 })
  end

  # Sort by the localized label at render time — `t` runs through
  # the request's locale, so the alphabetical order matches the
  # user's language. Values are explicitly `String`, not `Symbol`,
  # because Phlex's element attributes dasherize Symbols on
  # emission (`:herbarium_records` → `"herbarium-records"`) — the
  # controller reads exact `"herbarium_records"`, so a Symbol here
  # would silently break the search.
  def sorted_type_options
    SEARCH_TYPE_OPTIONS.map { |label, value| [label.ti, value.to_s] }.sort
  end

  def render_submit
    Button(
      type: :submit,
      variant: :outline, class: "px-2 text-nowrap"
    ) do
      span(class: "d-sm-none") do
        Icon(type: :search)
      end
      span(class: class_names(
        Components::Column.mobile_hide_classes(display: :inline)
      )) do
        plain(:app_search.l)
      end
    end
  end
end
