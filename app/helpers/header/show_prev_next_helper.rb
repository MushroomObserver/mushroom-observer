# frozen_string_literal: true

#  Prev/Index/Next object links for show templates
#
#  add_pager_for(object)        # add a prev/next pager for an object (show)
#
module Header
  module ShowPrevNextHelper
    # NOTE: Prev/Next only makes sense in the context of a query, so this UI
    # only displays if the current query is for the current type of object,
    # or for :rss_logs. We also need the query to figure out if we're at the
    # first or last, and therefore should hide the prev/next button.
    #
    def add_pager_for(object)
      return unless object && (query = show_page_incoming_query(object))

      content_for(:prev_next_object) do
        render(Components::ShowPrevNextNav.new(object: object, query: query))
      end
    end

    private

    # Returns the query if it's for the relevant type of object
    def show_page_incoming_query(object)
      return nil unless session[:query_record]

      query = controller.current_query
      return nil unless [object.type_tag, :rss_log].include?(query&.type_tag)

      # set current_id so prev_id and next_id will work
      query.current_id = object.id
      query
    end
  end
end
