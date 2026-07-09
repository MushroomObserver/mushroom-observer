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
  SEARCH_TYPE_OPTIONS = [
    [:COMMENTS, :comments],
    [:GLOSSARY, :glossary_terms],
    [:HERBARIA, :herbaria],
    [:HERBARIUM_RECORDS, :herbarium_records],
    [:LOCATIONS, :locations],
    [:NAMES, :names],
    [:OBSERVATIONS, :observations],
    [:PROJECTS, :projects],
    [:SPECIES_LISTS, :species_lists],
    [:USERS, :users],
    [:app_search_google, :google]
  ].freeze

  FORM_CLASS = "flex-bar flex-grow-1 navbar-form px-0 gap-2"

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
    div(class: "form-group has-feedback has-search d-flex " \
               "flex-grow-1 mb-0") do
      Icon(
        type: :search,
        html_class: "form-control-feedback hidden-xs"
      )
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
    div(class: "form-group text-nowrap mb-0") do
      select_field(:type, sorted_type_options,
                   label: false,
                   class: "form-control",
                   data: {
                     search_type_target: "select",
                     action: "search-type#getHelp search-type#getForm"
                   })
    end
  end

  # Sort by the localized label at render time — `t` runs through
  # the request's locale, so the alphabetical order matches the
  # user's language. Values are explicitly `String`, not `Symbol`,
  # because Phlex's element attributes dasherize Symbols on
  # emission (`:herbarium_records` → `"herbarium-records"`) — the
  # controller reads exact `"herbarium_records"`, so a Symbol here
  # would silently break the search.
  def sorted_type_options
    SEARCH_TYPE_OPTIONS.map { |label, value| [label.t, value.to_s] }.sort
  end

  def render_submit
    div(class: "form-group text-nowrap") do
      Button(
        type: :submit,
        variant: :outline, class: "px-2"
      ) do
        span(class: "d-sm-none") do
          Icon(type: :search)
        end
        span(class: "hidden-xs") { plain(:app_search.l) }
      end
    end
  end
end
