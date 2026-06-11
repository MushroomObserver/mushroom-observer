# frozen_string_literal: true

# Top-nav search bar. When the viewer is logged in, renders the
# Bootstrap collapse-trigger help toggle, the `PatternSearchForm`,
# and (off the `/search` action only) the form toggle that opens
# the advanced-search expander beneath the bar. When the viewer is
# anonymous, renders a `<strong>` "Login required" reminder.
#
# Replaces `app/views/controllers/application/top_nav/_search_bar.html.erb`.
# The `search_help_toggle` / `search_form_toggle` Bootstrap-collapse
# buttons (previously `SearchBarHelper` methods) are inlined as
# private renderers — `search_bar_toggle` was already inlined into
# `Components::SearchForm`, this finishes the job.
class Views::Layouts::TopNav::SearchBar < Views::Base
  BAR_TOGGLE_CLASSES = %w[btn btn-link navbar-link px-2].freeze

  # Search types that have a per-type help expander. Mirrors
  # `Views::Layouts::TopNav::SEARCH_HELP_TYPES`; passed through
  # so the bar can decide which toggle starts visible.
  prop :search_help_types, _Array(Symbol)
  # Search types whose advanced-search form is reachable via the
  # form-toggle. Mirrors `Views::Layouts::TopNav::SEARCH_FORM_TYPES`.
  prop :search_form_types, _Array(Symbol)

  def view_template
    if current_user
      render_logged_in
    else
      strong(class: "navbar-text mx-2 text-nowrap") do
        plain(:app_login_reminder.t)
      end
    end
  end

  private

  def render_logged_in
    div(class: "w-100", id: "search_nav_elements") do
      render_collapse_bar
      render_advanced_form_target unless on_search_page?
    end
  end

  def render_collapse_bar
    div(class: "collapse in w-100", id: "search_bar_elements",
        data: { search_type_target: "bar",
                action:
                  "$shown.bs.collapse->search-type#closeForm" }) do
      div(class: "navbar-flex w-100 gap-2") do
        render_help_toggle
        render(Components::PatternSearchForm.new(pattern_search_model))
        render_form_toggle unless on_search_page?
      end
      # Per-type help fragment is fetched into here by the
      # search-type Stimulus controller; empty on initial paint.
      div(class: "collapse w-100", id: "search_bar_help",
          data: { search_type_target: "help" })
    end
  end

  # Outer collapse wrapper that the search-type Stimulus
  # controller populates with whichever advanced-search form
  # matches the selected search type.
  def render_advanced_form_target
    div(class: "collapse w-100 border-top", id: "search_nav_form",
        data: { search_type_target: "form",
                action:
                  "$shown.bs.collapse->search-type#closeBar" })
  end

  # Bootstrap collapse-trigger button for the per-type help
  # fragment (`#search_bar_help`). Starts hidden via `d-none`
  # when the current search-type has no help content.
  def render_help_toggle
    button(
      class: bar_toggle_class(visible: help_visible?),
      type: "button",
      data: { toggle: "collapse",
              search_type_target: "helpToggle",
              target: "#search_bar_help" },
      aria: { expanded: "false", controls: "search_bar_help" }
    ) do
      render(Components::LinkIcon.new(
               type: :info, title: :search_bar_help.t
             ))
    end
  end

  # Bootstrap collapse-trigger button for the advanced-search
  # form expander (`#search_nav_form`). Starts hidden via
  # `d-none` when the current search-type has no advanced form.
  def render_form_toggle
    button(
      class: bar_toggle_class(visible: form_visible?),
      type: "button",
      data: { toggle: "collapse",
              search_type_target: "formToggle",
              target: "#search_nav_form" },
      aria: { expanded: "false", controls: "search_nav_form" }
    ) do
      render(Components::LinkIcon.new(
               type: :plus, title: :search_bar_more_options.l
             ))
    end
  end

  def bar_toggle_class(visible:)
    classes = BAR_TOGGLE_CLASSES.dup
    classes << "d-none" unless visible
    classes.join(" ")
  end

  def pattern_search_model
    FormObject::PatternSearch.new(
      pattern: session_pattern,
      type: default_search_type.to_s
    )
  end

  # `session[:search_type]` is written either by
  # `SearchController#pattern` (after it pluralizes the submitted
  # form value) or by `ApplicationController::Queries` (which
  # stores `Query#search_type`, already plural from the
  # controller's module name) — so the legacy "safe pluralize"
  # the original ERB ran is no longer needed.
  def default_search_type
    controller.session[:search_type]&.to_sym || :observations
  end

  def help_visible?
    @search_help_types.include?(default_search_type)
  end

  def form_visible?
    @search_form_types.include?(default_search_type)
  end

  def session_pattern
    controller.session[:pattern]
  end

  def on_search_page?
    controller.controller_name == "search"
  end
end
