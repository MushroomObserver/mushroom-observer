# frozen_string_literal: true

# Search bar. When the viewer is logged in, renders the
# Bootstrap collapse-trigger help toggle, the `PatternSearchForm`,
# and (off SearchController pages) the form toggle that opens
# the advanced-search expander beneath the bar. When the viewer is
# anonymous, renders a `<strong>` "Login required" reminder.
class Views::Layouts::SearchBar < Views::Base
  # Search types that have a per-type help expander. Mirrors
  # `Views::Layouts::SearchNav::SEARCH_HELP_TYPES`; passed through
  # so the bar can decide which toggle starts visible.
  prop :search_help_types, _Array(Symbol)
  # Search types whose advanced-search form is reachable via the
  # form-toggle. Mirrors `Views::Layouts::SearchNav::SEARCH_FORM_TYPES`.
  prop :search_form_types, _Array(Symbol)

  def view_template
    if current_user
      render_logged_in
    else
      render(Components::Navbar::Text.new(element: :strong,
                                          class: "mx-2 text-nowrap")) do
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
    Collapsible(id: "search_bar_elements",
                expanded: on_search_page? || !advanced_default?,
                class: "w-100",
                data: {
                  search_type_target: "bar",
                  action: "$shown.bs.collapse->search-type#closeForm"
                }) do
      div(class: "flex-bar w-100 gap-2") do
        render_help_toggle
        render(Components::Form::PatternSearch.new(pattern_search_model))
        render_form_toggle unless on_search_page?
      end
      # Per-type help fragment is fetched into here by the
      # search-type Stimulus controller; empty on initial paint.
      Collapsible(id: "search_bar_help", class: "w-100",
                  data: { search_type_target: "help" })
    end
  end

  # Outer collapse wrapper that the search-type Stimulus
  # controller populates with whichever advanced-search form
  # matches the selected search type.
  def render_advanced_form_target
    Collapsible(id: "search_nav_form", expanded: advanced_default?,
                class: "w-100",
                data: { search_type_target: "form",
                        action: "$shown.bs.collapse->search-type#closeBar" })
  end

  # Bootstrap collapse-trigger for the per-type help fragment
  # (`#search_bar_help`). Starts hidden via `d-none` when the
  # current search-type has no help content.
  def render_help_toggle
    Link(type: :collapse_toggle,
         target_id: "search_bar_help",
         icon: :info,
         icon_title: :search_bar_help.l,
         button: :link, size: :lg,
         class: toggle_class(visible: help_visible?),
         data: { search_type_target: "helpToggle" })
  end

  # Owns the `formToggle` Stimulus target and its `d-none` availability
  # toggle -- the `Link`s below carry only responsive classes, since a
  # static `d-none` here would lose to `d-lg-inline-block` at the
  # breakpoint (later in `_utilities.scss`'s source order).
  def render_form_toggle
    div(class: availability_class(visible: form_visible?),
        data: { search_type_target: "formToggle" }) do
      render_form_toggle_icon
      render_form_toggle_button
    end
  end

  # Icon-only toggle, shown below `lg`.
  def render_form_toggle_icon
    Link(type: :collapse_toggle,
         target_id: "search_nav_form",
         collapsed: !advanced_default?,
         icon: :plus,
         icon_title: :search_bar_more_options.l,
         button: :link, size: :lg,
         class: class_names("p-0", Components::Column.visibility_classes(
                                     hide_at: :lg
                                   )))
  end

  # Labeled outline-button toggle, shown from `lg` up.
  def render_form_toggle_button
    Link(type: :collapse_toggle,
         target_id: "search_nav_form",
         collapsed: !advanced_default?,
         button: :outline,
         class: class_names(Components::Column.visibility_classes(
                              hide_at: :xs, show_at: :lg,
                              display: :"inline-block"
                            ))) { :search_bar_more_options.l }
  end

  def toggle_class(visible:)
    classes = ["p-0"]
    classes << "d-none" unless visible
    classes.join(" ")
  end

  def availability_class(visible:)
    visible ? nil : "d-none"
  end

  def advanced_default?
    controller.session[:search_view] == "advanced"
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
  # controller's module name). The latter stores it for EVERY
  # query-backed index — including types the select has no option
  # for (e.g. `:rss_logs` from the Activity Log). An unselectable
  # value would leave the browser showing the first alphabetical
  # option ("Comments"), so those fall back to :observations
  # (#4969).
  def default_search_type
    type = controller.session[:search_type]&.to_sym
    return type if Components::Form::PatternSearch::TYPE_VALUES.include?(type)

    :observations
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
