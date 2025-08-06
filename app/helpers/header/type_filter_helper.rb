# frozen_string_literal: true

#  add_type_filters             # add content_for(:type_filters)
#
module Header
  module TypeFilterHelper
    # Different from sorting links: type_filters
    # currently only used in RssLogsController#index
    def add_type_filters
      content_for(:type_filters) do
        render(partial: "application/content/type_filters")
      end
    end

    # The "Everything" tab
    def filter_for_everything(types)
      label = :rss_all.t
      link = activity_logs_path(params: { type: :all })
      help = { title: :rss_all_help.t, class: "filter-only" }
      types == ["all"] ? label : link_with_query(label, link, **help)
    end

    # A single tab
    def filter_for_type(types, type)
      label = :"rss_one_#{type}".t
      link = activity_logs_path(params: { type: type })
      help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
      types == [type] ? label : link_with_query(label, link, **help)
    end
  end
end
