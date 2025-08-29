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

    # The "Everything" tab
    def filter_for_everything(query, types)
      label = :rss_all.t

      link = activity_logs_path(
        params: { q: q_param(query).merge(type: :all) }
      )
      help = { title: :rss_all_help.t, class: "filter-only" }
      types == ["all"] ? label : link_with_query(label, link, **help)
    end

    # A single tab
    def filter_for_type(query, types, type)
      label = :"rss_one_#{type}".t
      link = activity_logs_path(
        params: { q: q_param(query).merge(type:) }
      )
      help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
      types == [type] ? label : link_with_query(label, link, **help)
    end
  end
end
