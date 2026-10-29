# frozen_string_literal: true

# Type-filter row for an index page -- "Show:" plus one filter per
# `filterable_types:` entry, highlighting the active selection.
#
# `multiple: true` -- checkboxes in a `<form>` (dropdown below the
# 1500px cutoff, inline bar above it), Apply + Save-as-Default.
# Activity Logs: several types at once, round-trips through
# `Query#types`.
#
# `multiple: false` -- plain filter links, one type at a time, no
# form. Interests: no multi-select concept, so the caller supplies
# `type_label:`/`path_for:` procs instead of a Query.
class Components::TypeFilters < Components::Base
  prop :multiple, _Boolean
  # The universe of types to render a filter/checkbox for, in
  # display order -- not necessarily every `ALL_TYPE_TAGS` value
  # (Interests only lists types the user has interests in).
  prop :filterable_types, _Array(Symbol)
  # Current selection: `["all"]`, or one-or-more type-tag strings.
  prop :types, _Array(::String)

  # `multiple: true` only (Activity Logs' Query/account-preferences
  # integration -- irrelevant, and left nil, when `multiple: false`).
  prop :query, _Nilable(::Query), default: nil
  prop :user, _Nilable(::User), default: nil
  # Suffixes element ids so a :top/:bottom pair of renders doesn't
  # collide (see Views::FullPageBase::IndexNav#add_type_filters).
  prop :position, ::Symbol, default: -> { :top }

  # `multiple: false` only -- Interests has no shared route-building
  # or label-building scheme with Activity Logs' `rss_one_<type>`/
  # `activity_logs_path(q: ...)`, so the caller supplies both.
  # type_label: (Symbol) -> String : path_for: (Symbol | nil) -> String
  prop :type_label, _Nilable(Proc), default: nil
  prop :path_for, _Nilable(Proc), default: nil
  # Whether to render the "Show:" lead-in -- false when a second
  # filter sits beside this one in the same row and the first filter
  # already carries it (see Interests::Index#view_template).
  prop :show_intro, _Boolean, default: true
  # Disambiguates element ids when two `multiple: false` filters
  # render at the same `position:` (e.g. a type filter and a state
  # filter both at :top).
  prop :key, ::Symbol, default: -> { :type }

  # Save-Defaults needs a CSRF token (it's a POST); Apply's GET
  # doesn't.
  register_value_helper :form_authenticity_token

  include MultiSelect

  def view_template
    if @multiple
      render_dropdown_filter_form
      render_bar_filter_form
    else
      render_single_select_dropdown
      render_single_select_bar
    end
  end

  private

  # ---- multiple: false (Interests) ----
  #
  # Same dropdown/bar, 1500px-cutoff split as the multiple: true
  # forms below (`.filter-form-dropdown`/`.filter-form-bar` in
  # _dropdowns.scss) -- plain divs, not forms: each option navigates
  # directly, no Apply/Save-default to submit.

  def render_single_select_dropdown
    div(class: "filter-form-dropdown") do
      div(class: "flex-bar") do
        if @show_intro
          render(Components::Navbar::Text.new(class: "mx-0 pr-2")) do
            :rss_show.t
          end
        end
        Dropdown(
          id: "type_filter_toggle_#{@key}_#{@position}",
          menu_id: "type_filter_menu_#{@key}_#{@position}",
          label: single_select_toggle_label, element: :div,
          wrapper_class: class_names(Components::Navbar::FORM_CLASS, "px-0"),
          toggle_variant: :outline, toggle_class: "font-weight-normal",
          menu_content: capture { render_single_select_dropdown_items }
        )
      end
    end
  end

  def single_select_toggle_label
    return :rss_all.t if @types == ["all"]

    @type_label.call(@types.first.to_sym)
  end

  def render_single_select_dropdown_items
    render_type_filter_dropdown(nil)
    @filterable_types.each { |type| render_type_filter_dropdown(type) }
  end

  def render_type_filter_dropdown(type)
    if type_filter_active?(type)
      div(class: "dropdown-item active") { plain(type_filter_label(type)) }
    else
      Link(type: :get, name: type_filter_label(type),
           target: @path_for.call(type), class: "dropdown-item") do
        plain(type_filter_label(type))
      end
    end
  end

  def render_single_select_bar
    div(class: "filter-form-bar") do
      div(class: "text-nowrap") do
        render_show_label if @show_intro
        ButtonGroup do
          render_type_filter_bar(nil)
          @filterable_types.each { |type| render_type_filter_bar(type) }
        end
      end
    end
  end

  def render_type_filter_bar(type)
    active = type_filter_active?(type)
    Button(tag: :span, variant: :outline, size: :sm,
           class: ("active" if active)) do
      if active
        plain(type_filter_label(type))
      else
        Link(type: :get, name: type_filter_label(type),
             target: @path_for.call(type)) { plain(type_filter_label(type)) }
      end
    end
  end

  def type_filter_active?(type)
    @types == [type.to_s.presence || "all"]
  end

  def type_filter_label(type)
    type ? @type_label.call(type) : :rss_all.l
  end
end
