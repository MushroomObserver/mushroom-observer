# frozen_string_literal: true

#  add_type_filters             # add content_for(:type_filters)
#
module Header
  module TypeFilterHelper
    # Different from sorting links: type_filters
    # currently only used in RssLogsController#index
    def add_type_filters(query, types)
      content_for(:type_filters) do
        render(
          partial: "application/content/type_filters",
          locals: { query:, types: }
        )
      end
    end

    def type_checkbox_with_button(query, types, type, form)
      check_button_with_label(
        form:, field: type,
        checked: types.include?(type) || types == ["all"],
        label: filter_for_type(query, types, type),
        checked_value: type,
        id: "type_#{type}",
        class: class_names("filter-checkbox my-0", { active: types == [type] })
      )
    end

    # Creates hidden fields for existing query params (except type, which comes
    # from checkboxes). This preserves filters like created_at, order_by, etc.
    def query_params_hidden_fields(query, form)
      return "".html_safe unless query

      q = q_param(query).except(:type)
      query_string = { q: q }.to_query
      pairs = query_string.split("&")
      tags = pairs.map do |pair|
        key, value = pair.split("=", 2).map { |str| CGI.unescape(str) }
        form.hidden_field(key, value:)
      end
      tags.safe_join("\n")
    end

    # Creates checkbox with array-style name: q[type][]=observation
    # This allows multiple types to be selected and submitted as an array
    # Label includes a link for click-to-filter functionality
    def type_array_checkbox(query, types, type)
      checked = types.include?(type) || types == ["all"]
      wrap_class = class_names("btn btn-default btn-sm filter-checkbox my-0",
                               { active: types == [type] })

      tag.label(class: wrap_class) do
        [
          check_box_tag("q[type][]", type, checked,
                        id: "type_#{type}", class: "mt-0 mr-2"),
          filter_for_type(query, types, type)
        ].safe_join
      end
    end

    # The "Everything" tab
    # Uses link_to (not link_with_query) since we build the full q param here
    def filter_for_everything(query, types)
      label = :rss_all.t
      return label if types == ["all"]

      link = activity_logs_path(q: q_param(query).merge(type: "all"))
      link_to(label, link, title: :rss_all_help.t, class: "filter-only")
    end

    # A single tab
    # Uses link_to (not link_with_query) since we build the full q param here
    def filter_for_type(query, types, type)
      label = :"rss_one_#{type}".t
      return label if types == [type]

      link = activity_logs_path(q: q_param(query).merge(type:))
      link_to(label, link, title: :rss_one_help.t(type: type.to_sym),
                           class: "filter-only")
    end
  end
end
