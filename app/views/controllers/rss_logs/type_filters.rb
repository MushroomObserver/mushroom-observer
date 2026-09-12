# frozen_string_literal: true

# Type-filter form for the rss_logs (activity logs) index. Renders
# a row of checkbox buttons (one per RssLog type) plus an "all"
# button and an Apply submit.
module Views::Controllers::RssLogs
  class TypeFilters < Views::Base
    prop :query, _Nilable(::Query)
    prop :types, _Array(::String)
    prop :user, _Nilable(::User), default: nil

    # Only the Save-Defaults button needs this (its formmethod="post"
    # override is a state-changing request); the Apply button's plain
    # GET is exempt from CSRF checks entirely.
    register_value_helper :form_authenticity_token

    # Not a Superform -- a multi-select checkbox filter, not a
    # single-model-bound field set. Submitting the combined state of
    # several independently-toggled checkboxes as one q[types][] array
    # needs a submit, unlike IndexPaginationNav's single-value goto
    # controls, which each fully specify their own destination and so
    # reduce to plain links.
    # rubocop:disable-next MO/NoHandRolledFormTag
    def view_template
      form(action: activity_logs_path, method: :get,
           class: "filter-form", id: "log_filter_form",
           data: { turbo: "false" }) do
        render_hidden_fields
        render_filter_buttons
      end
    end

    private

    def render_hidden_fields
      # `formmethod="post"` is the only verb HTML5 allows on a button
      # override -- Rack::MethodOverride reads `_method` to route the
      # Save-Defaults POST to Account::Preferences#update (PATCH).
      # Inert for the Apply button's GET submission: MethodOverride
      # only inspects `_method` on a POST request.
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "authenticity_token",
            value: form_authenticity_token)
      # Only reached by the plain-HTML fallback path (no JS/Turbo) --
      # sends the user back to the activity log instead of the
      # account prefs edit page. The Turbo path stays on this page
      # regardless. `back` is an enum key, not a URL -- see
      # Account::PreferencesController::BACK_DESTINATIONS.
      input(type: "hidden", name: "back", value: "rss_logs")
      return unless @query

      query_params_except_types.each do |key, value|
        input(type: "hidden", name: key, value: value)
      end
    end

    def render_filter_buttons
      # "Show:" label sits OUTSIDE the .btn-group: BS3 `.btn-group`
      # floats and inline-blocks its children expecting `.btn`-shaped
      # elements, and a non-`.btn` span inside breaks the layout (the
      # span ends up after the group). Sibling-of-group keeps it
      # inline-aligned without being subject to the group's layout
      # rules.
      div(class: class_names("px-3 pb-1 text-nowrap",
                             Components::Column.mobile_hide_classes)) do
        render_show_label
        ButtonGroup do
          render_everything_button
          render_type_buttons
          render_submit_button
          render_save_default_button
        end
      end
    end

    # Inline label for the whole filter group. Was rendered as a
    # disabled btn-default to share vertical rhythm with the other
    # button-styled controls, but that's misleading (looks like a
    # button you can't press). Plain text with `text-muted` and
    # margin matches the BS3 caption-style without the affordance.
    def render_show_label
      span(class: "text-muted mr-2") { :rss_show.t }
    end

    def render_everything_button
      Button(
        tag: :span,
        variant: :outline,
        size: :sm,
        class: ("active" if @types == ["all"])
      ) { filter_for_everything }
    end

    def render_type_buttons
      RssLog::ALL_TYPE_TAGS.map(&:to_s).each do |type|
        render_type_checkbox(type)
      end
    end

    # "Apply" reads more naturally than "Submit" for a filter-
    # narrowing action where there's nothing being created. The
    # filter buttons use `.btn-outline-default` (subtle, input-
    # style); the Apply button uses the solid `.btn-default` so it
    # stands out as the commit action.
    def render_submit_button
      Button(type: :submit, name: :apply.ti, size: :sm)
    end

    # A second submit button on the same form as "Apply," targeting a
    # different action via `formaction`/`formmethod` -- whatever's
    # checked at the moment of click is what gets saved, the same
    # values "Apply" would filter by. `data-turbo="true"` opts just
    # this button into Turbo, overriding the form's own
    # `data-turbo="false"`, so the response is a flash-only
    # confirmation with no page navigation.
    def render_save_default_button
      return unless show_make_default?

      Button(type: :submit, name: :rss_make_default.t, variant: :outline,
             size: :sm, formaction: account_preferences_path,
             formmethod: "post", data: { turbo: "true" })
    end

    # Individual type checkbox styled as a Bootstrap button. Routes
    # through `ButtonStyleCheckbox` so the markup stays in lockstep
    # with the rest of MO's button-style radio/checkbox helpers
    # (BS3/4/5 migration changes one file, not many). The "pressed"
    # active state is CSS-only via `.filter-checkbox:has(input:checked)`
    # in `_form_elements.scss`.
    def render_type_checkbox(type)
      render(::Components::ApplicationForm::ButtonStyleCheckbox.new(
               name: "q[types][]", value: type,
               id: "type_#{type}", checked: type_checked?(type),
               variant: :outline, size: :sm,
               label: { class: "filter-checkbox my-0" },
               class: "mt-0 mr-2"
             )) do
        filter_for_type(type)
      end
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
