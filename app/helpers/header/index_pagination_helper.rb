# frozen_string_literal: true

module Header
  module IndexPaginationHelper
    def add_pagination(pagination_data, args = {})
      content_for(:index_pagination_top) do
        render_index_pagination(pagination_data, args, position: :top)
      end
      return unless pagination_data && pagination_data.num_pages > 1

      content_for(:index_pagination_bottom) do
        render_index_pagination(pagination_data, args, position: :bottom)
      end
    end

    # Wrap a block in pagination links. Includes letters if appropriate.
    def paginated_results(args = {}, &block)
      html_id = args[:html_id] ||= "results"
      results = capture(&block).to_s
      uri = URI.parse(observations_path(q: q_param))
      encoded_q = uri.query

      tag.div(id: html_id, data: { q: encoded_q }) do
        concat(content_for(:index_pagination_top))
        concat(results)
        concat(content_for(:index_pagination_bottom))
      end
    end

    private

    def render_index_pagination(pagination_data, args, position:)
      render(Components::IndexPagination.new(
               pagination_data: pagination_data,
               position: position,
               args: args,
               request_url: request_url_for_links,
               form_action_url: form_action_url,
               q_params: q_param(query_from_session),
               letter_param: params[:letter]
             )) do |component|
        component.with_sorter { content_for(:sorter) } if content_for?(:sorter)
      end
    end

    # Full request URL (without host) for generating pagination link URLs
    def request_url_for_links
      request.url.sub(%r{^\w+:/+[^/]+}, "")
    end

    # For the page input form, give form the current url without query string
    def form_action_url
      parsed_url = URI.parse(request.url)
      parsed_url.fragment = parsed_url.query = nil
      parsed_url.to_s
    end
  end
end
