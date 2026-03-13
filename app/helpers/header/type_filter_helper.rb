# frozen_string_literal: true

#  add_type_filters             # add content_for(:type_filters)
#
module Header
  module TypeFilterHelper
    # Different from sorting links: type_filters
    # currently only used in RssLogsController#index
    def add_type_filters(query, types)
      content_for(:type_filters) do
        render(Components::ActivityLogTypeFilters.new(query:, types:))
      end
    end
  end
end
