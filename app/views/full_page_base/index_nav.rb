# frozen_string_literal: true

# Index-page nav mixed into `Views::FullPageBase`.
#
# `add_pagination`, `add_sorter`, `add_type_filters` stash their
# respective Phlex sub-view's HTML into a `content_for` slot that the
# layout's index-bar reads on every index action.
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
  def add_type_filters(query, types)
    content_for(:type_filters) do
      capture do
        render(::Views::Controllers::RssLogs::TypeFilters.new(
                 query: query, types: types
               ))
      end
    end
  end

  private

  def render_index_pagination(pagination_data, args, position)
    render(::Views::Layouts::Header::IndexPaginationNav.new(
             pagination_data: pagination_data,
             position: position,
             anchor: args[:anchor],
             request_url: request_url_for_links,
             form_action_url: form_action_url,
             letter_param: string_param(:letter)
           )) do |component|
      if content_for?(:sorter)
        component.with_sorter { trusted_html(content_for(:sorter)) }
      end
    end
  end

  # Full request URL (without host) for generating pagination link URLs.
  def request_url_for_links
    request.url.sub(%r{^\w+:/+[^/]+}, "")
  end

  # For the page-input form, give it the current URL without query
  # string — the form serializes its own query params.
  def form_action_url
    parsed = URI.parse(request.url)
    parsed.fragment = parsed.query = nil
    parsed.to_s
  end
end
