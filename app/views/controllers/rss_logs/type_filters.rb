# frozen_string_literal: true

# Type-filter row for the rss_logs index: checkbox buttons per
# RssLog type, plus an "all" button and an Apply submit.
module Views::Controllers::RssLogs
  class TypeFilters < Views::Base
    prop :query, _Nilable(::Query)
    prop :types, _Array(::String)
    prop :user, _Nilable(::User), default: nil
    # Suffixes element ids so a :top/:bottom pair of renders doesn't
    # collide (see Views::FullPageBase::IndexNav#add_type_filters).
    prop :position, ::Symbol, default: -> { :top }

    # Save-Defaults needs a CSRF token (it's a POST); Apply's GET
    # doesn't.
    register_value_helper :form_authenticity_token

    # Below xl: a stacked Dropdown. At xl+: the original inline
    # btn-group. Two separate <form>s, not one responsive layout --
    # only the visible form's submit button is reachable, so only
    # its checkboxes submit. No JS needed to keep them in sync.
    def view_template
      render_dropdown_filter_form
      render_bar_filter_form
    end

    private

    # No named Bootstrap breakpoint fits the bar -- it needs more
    # room alongside the pager than even xl (1320px) comfortably
    # gives it, so this is a custom 1500px cutoff (see
    # .filter-form-dropdown/.filter-form-bar in _form_elements.scss),
    # not Components::Column.visibility_classes.
    def render_dropdown_filter_form
      # rubocop:disable-next MO/NoHandRolledFormTag
      form(action: activity_logs_path, method: :get,
           class: "filter-form filter-form-dropdown",
           id: "log_filter_form_dropdown_#{@position}",
           data: { turbo: "false" }) do
        render_hidden_fields
        render_dropdown_filter
      end
    end

    def render_bar_filter_form
      # rubocop:disable-next MO/NoHandRolledFormTag
      form(action: activity_logs_path, method: :get,
           class: "filter-form filter-form-bar",
           id: "log_filter_form_bar_#{@position}",
           data: { turbo: "false" }) do
        render_hidden_fields
        render_bar_filter
      end
    end

    def render_hidden_fields
      # _method routes Save-Defaults' formmethod="post" override to
      # Account::Preferences#update; inert for Apply's plain GET.
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "authenticity_token",
            value: form_authenticity_token)
      # Non-JS fallback only -- returns to the activity log, not the
      # account-prefs edit page.
      input(type: "hidden", name: "back", value: "rss_logs")
      return unless @query

      query_params_except_types.each do |key, value|
        input(type: "hidden", name: key, value: value)
      end
    end

    # "Show:" sits outside the dropdown, like Header::Sorter's
    # "Sort by:". The toggle shows the live selection when there's a
    # single clean word for it, else falls back to "Show:".
    def render_dropdown_filter
      div(class: "flex-bar") do
        render(Components::Navbar::Text.new(class: "mx-0 pr-2")) do
          :rss_show.t
        end
        Dropdown(
          id: "log_filter_toggle_#{@position}",
          menu_id: "log_filter_menu_#{@position}",
          label: dropdown_toggle_label, element: :div,
          wrapper_class: class_names(Components::Navbar::FORM_CLASS, "px-0"),
          toggle_variant: :outline, toggle_class: "font-weight-normal",
          menu_content: capture { render_dropdown_items }
        )
      end
    end

    def dropdown_toggle_label
      return :rss_all.t if @types == ["all"]
      return :"rss_one_#{@types.first}".t if single_known_type?

      :rss_selected.t
    end

    # `@types` can also be `["none"]` (RssLogsController's sentinel
    # for "no valid type survived"), which has no `rss_one_*` tag.
    def single_known_type?
      @types.size == 1 &&
        RssLog::ALL_TYPE_TAGS.map(&:to_s).include?(@types.first)
    end

    # Raw `menu_content:`, not `menu.section(...)` -- these rows
    # don't fit the link-tuple shape `section` expects.
    #
    # type-filters: keeps the menu open on a checkbox click, and
    # disables Apply until a checkbox's state changes.
    def render_dropdown_items
      div(class: "type-filter-menu",
          data: { controller: "type-filters",
                  action: "click->type-filters#stop:stop " \
                          "change->type-filters#checkChanged" }) do
        render_everything_dropdown
        RssLog::ALL_TYPE_TAGS.map(&:to_s).each do |type|
          render_type_checkbox_dropdown(type)
        end
        div(class: "dropdown-item disabled",
            data: { type_filters_target: "submitItem" }) do
          render_submit_button_dropdown
        end
        render_save_default_row
      end
    end

    def render_save_default_row
      return unless show_make_default?

      div(class: "dropdown-item") { render_save_default_button_dropdown }
    end

    def render_bar_filter
      div(class: "text-nowrap") do
        render_show_label
        ButtonGroup do
          render_everything_bar
          RssLog::ALL_TYPE_TAGS.map(&:to_s).each do |type|
            render_type_checkbox_bar(type)
          end
          render_submit_button
          render_save_default_button
        end
      end
    end

    def render_show_label
      span(class: "mr-2") { :rss_show.t }
    end

    def render_everything_bar
      Button(
        tag: :span, variant: :outline, size: :sm,
        class: ("active" if @types == ["all"])
      ) { filter_for_everything }
    end

    # Empty checkbox-zone-width spacer, no checkbox -- aligns this
    # row's label with the checkbox rows' label-zone text.
    def render_everything_dropdown
      Button(
        tag: :span, variant: :strip,
        class: class_names("dropdown-item d-flex align-items-center",
                           ("active" if @types == ["all"]))
      ) do
        div(class: "checkbox-zone")
        div(class: "label-zone flex-grow-1") { filter_for_everything }
      end
    end

    # Solid button -- the commit action, distinct from the outline
    # filter buttons beside it.
    def render_submit_button
      Button(type: :submit, name: :apply.ti, size: :sm)
    end

    def render_save_default_button
      return unless show_make_default?

      Button(type: :submit, name: :rss_make_default.t, variant: :outline,
             size: :sm, formaction: account_preferences_path,
             formmethod: "post", data: { turbo: "true" })
    end

    def render_submit_button_dropdown
      Button(type: :submit, name: :apply.ti, variant: :link,
             class: "text-nowrap p-0", disabled: true,
             data: { type_filters_target: "submit" })
    end

    def render_save_default_button_dropdown
      Button(type: :submit, name: :rss_make_default.t, variant: :link,
             class: "text-nowrap p-0",
             formaction: account_preferences_path,
             formmethod: "post", data: { turbo: "true" })
    end

    # Pressed state is CSS-only via .filter-checkbox:has(:checked).
    def render_type_checkbox_bar(type)
      render(::Components::ApplicationForm::ButtonStyleCheckbox.new(
               name: "q[types][]", value: type,
               id: "type_#{type}_#{@position}", checked: type_checked?(type),
               variant: :outline, size: :sm,
               label: { class: "filter-checkbox my-0" }
             )) { filter_for_type(type) }
    end

    # Different id than the bar's copy; stacked dropdown-item instead
    # of a button pill.
    def render_type_checkbox_dropdown(type)
      render(::Components::ApplicationForm::ButtonStyleCheckbox.new(
               name: "q[types][]", value: type,
               id: "type_#{type}_dropdown_#{@position}",
               checked: type_checked?(type), variant: :strip,
               label: { class: "dropdown-item filter-checkbox" },
               data: { type_filters_target: "checkbox" }
             )) { filter_for_type(type) }
    end

    # "Everything" filter - returns label or link
    def filter_for_everything
      label_text = :rss_all.t
      return plain(label_text) if @types == ["all"]

      link = activity_logs_path(q: query_params_with_types(["all"]))
      a(href: link, title: :rss_all_help.t, class: "filter-only") do
        label_text
      end
    end

    # Individual type filter - returns label or link
    def filter_for_type(type)
      label_text = :"rss_one_#{type}".t
      return plain(label_text) if @types == [type]

      link = activity_logs_path(q: query_params_with_types([type]))
      a(href: link,
        title: :rss_one_help.t(type: type.to_sym),
        class: "filter-only") { label_text }
    end

    # Query param helpers

    def type_checked?(type)
      @types.include?(type) || @types == ["all"]
    end

    def show_make_default?
      @user && @user.default_rss_type.to_s.split.sort != @types
    end

    def query_params_except_types
      return {} unless @query

      q = q_param(@query).except(:types)
      # Convert { q: { model: "RssLog" } }.to_query to key/value pairs
      query_string = { q: q }.to_query
      pairs = query_string.split("&")
      pairs.to_h do |pair|
        key, value = pair.split("=", 2).map { |str| CGI.unescape(str) }
        [key, value]
      end
    end

    def query_params_with_types(types)
      return { types: types } unless @query

      q_param(@query).merge(types: types)
    end
  end
end
