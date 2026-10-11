# frozen_string_literal: true

# Index-page nav mixed into `Views::FullPageBase`.
#
# `add_pagination`, `add_sorter`, `add_type_filters` stash what the
# layout's index-bar needs to render its sub-views on every index
# action -- `add_pagination`/`add_sorter` via a `content_for` slot,
# `add_type_filters` via a plain ivar (see the comment on that method
# for why).
#
# `paginated_results` (the body wrapper that emits the result-set
# `<div>` with the pagination strips woven around the block) lives on
# `Views::Base` — sub-partials that own the results body
# (`Shared::ImagesToReuseForm`, `VisualGroups::ImageMatrix`, etc.)
# call it too, and they don't inherit from `FullPageBase`.
module Views::FullPageBase::IndexNav
  # Top + bottom pagination strips. Skips the bottom strip when there's
  # only one page — no need to repeat the (already empty) "page 1 of 1"
  # at the bottom of a short result list.
  def add_pagination(pagination_data, args = {})
    content_for(:index_pagination_top) do
      capture { render_index_pagination(pagination_data, args, :top) }
    end
    return unless pagination_data && pagination_data.num_pages > 1

    content_for(:index_pagination_bottom) do
      capture { render_index_pagination(pagination_data, args, :bottom) }
    end
  end

  # Sort-bar dropdown. The Phlex view bails on its own when there's
  # nothing to sort, so no guard here.
  def add_sorter(query, sorts, link_all: false)
    content_for(:sorter) do
      capture do
        render(::Views::Layouts::Header::Sorter.new(
                 query: query, sorts: sorts, link_all: link_all
               ))
      end
    end
  end

  # Type-filter row above the RssLogs index — checkboxes that drop
  # query types in/out of the result set. Used only by
  # `RssLogsController#index` today.
  #
  # Stashes the args, not pre-rendered HTML -- unlike `add_sorter`,
  # `TypeFilters` renders element ids (form/toggle/checkbox ids) that
  # must stay unique if both the top and bottom pagination rows
  # render on the same page. `render_index_pagination` below renders
  # a fresh `TypeFilters` per position instead of reusing one capture,
  # so each copy's ids get position-suffixed.
  def add_type_filters(query, types, user: nil)
    @type_filters_args = { query: query, types: types, user: user }
  end

  private

  def render_index_pagination(pagination_data, args, position)
    render(::Views::Layouts::Header::IndexPaginationNav.new(
             pagination_data: pagination_data,
             position: position,
             anchor: args[:anchor],
             request_url: request_url_for_links
           )) do |component|
      if content_for?(:sorter)
        component.with_sorter { trusted_html(content_for(:sorter)) }
      end
      if @type_filters_args
        component.with_type_filters do
          render(::Views::Controllers::RssLogs::TypeFilters.new(
                   **@type_filters_args, position: position
                 ))
        end
      end
    end
  end

  # Full request URL (without host) for generating pagination link URLs.
  def request_url_for_links
    request.url.sub(%r{^\w+:/+[^/]+}, "")
  end
end
