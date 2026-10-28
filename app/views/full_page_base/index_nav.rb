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

  # Type-filter row for an index page -- kwargs forwarded as-is to
  # `Components::TypeFilters.new`. Callable more than once to stack
  # filters side by side (e.g. Interests' type + state filters).
  #
  # Stashes the args, not pre-rendered HTML -- `TypeFilters` renders
  # element ids that must stay unique per :top/:bottom position, so
  # `render_index_pagination` below builds a fresh instance each time
  # instead of reusing one capture.
  def add_type_filters(**args)
    (@type_filters_args ||= []) << args
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
          @type_filters_args.each do |args|
            render(::Components::TypeFilters.new(**args, position: position))
          end
        end
      end
    end
  end

  # Full request URL (without host) for generating pagination link URLs.
  def request_url_for_links
    request.url.sub(%r{^\w+:/+[^/]+}, "")
  end
end
