# frozen_string_literal: true

# Type-filter row for an index page -- "Show:" plus one pill per
# `filterable_types:` entry, highlighting the active selection.
#
# `multiple: true` -- checkboxes in a `<form>` (dropdown below the
# 1500px cutoff, inline bar above it), Apply + Save-as-Default.
# Activity Logs: several types at once, round-trips through
# `Query#types`.
#
# `multiple: false` -- plain link pills, one type at a time, no
# form. Interests: no multi-select concept, so the caller supplies
# `type_label:`/`path_for:` procs instead of a Query.
class Components::TypeFilters < Components::Base
  prop :multiple, _Boolean
  # The universe of types to render a pill/checkbox for, in display
  # order -- not necessarily every `ALL_TYPE_TAGS` value (Interests
  # only lists types the user has interests in).
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
        render(Components::Navbar::Text.new(class: "mx-0 pr-2")) do
          :rss_show.t
        end
        Dropdown(
          id: "type_filter_toggle_#{@position}",
          menu_id: "type_filter_menu_#{@position}",
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
    render_single_dropdown_item(nil, :rss_all.l, @path_for.call(nil))
    @filterable_types.each do |type|
      render_single_dropdown_item(type, @type_label.call(type),
                                  @path_for.call(type))
    end
  end

  def render_single_dropdown_item(type, label, url)
    if @types == [type.to_s.presence || "all"]
      div(class: "dropdown-item active") { plain(label) }
    else
      Link(type: :get, name: label, target: url,
           class: "dropdown-item") { plain(label) }
    end
  end

  def render_single_select_bar
    div(class: "filter-form-bar") do
      ButtonGroup(class: "text-nowrap") do
        Button(name: :rss_show.l, tag: :span, size: :sm, class: "disabled")
        render_single_pill(nil, :rss_all.l, @path_for.call(nil))
        @filterable_types.each do |type|
          render_single_pill(type, @type_label.call(type),
                             @path_for.call(type))
        end
      end
    end
  end

  def render_single_pill(type, label, url)
    active = (@types == [type.to_s.presence || "all"])
    Button(tag: :span, size: :sm, class: ("active" if active)) do
      if active
        plain(label)
      else
        Link(type: :get, name: label, target: url) { plain(label) }
      end
    end
  end
end
