# frozen_string_literal: true

# Show-page prev/next pager mixed into `Views::FullPageBase`.
#
# Renders an `<prev | index | next>` triplet at the top of a show
# page, but only when the page is reached through an index query that
# covers the object's type (or `:rss_log` covering it). Without a
# matching incoming query the prev/next IDs don't make sense, so the
# setter no-ops and the layout's slot stays empty.
module Views::FullPageBase::ShowPager
  def add_pager_for(object)
    return unless object && (query = show_page_incoming_query(object))

    content_for(:prev_next_object) do
      capture do
        render(::Views::Layouts::Header::ShowPrevNextNav.new(
                 object: object, query: query
               ))
      end
    end
  end

  private

  # Returns the current query iff it's for `object`'s type (or
  # `:rss_log` covering it). Sets `current_id` on the query so the
  # prev/next pager can compute neighbors.
  def show_page_incoming_query(object)
    return nil unless session[:query_record]

    query = current_query
    return nil unless [object.type_tag, :rss_log].include?(query&.type_tag)

    query.current_id = object.id
    query
  end
end
