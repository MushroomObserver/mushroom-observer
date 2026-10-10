# frozen_string_literal: true

module Views::Controllers::Locations
  # Index page — paginated list of known locations. Used by
  # `LocationsController#index` and its filtered_index dispatch.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :locations, _Array(::Location)
    prop :pagination_data, ::PaginationData
    # `{ location_id => observation_count }`, built in the controller.
    prop :observation_counts, _Hash(::Integer, ::Integer)

    def view_template
      register_chrome

      Container(width: :text_image, class: "mt-3") do
        render_locations
      end
    end

    private

    def register_chrome
      container_class(:full)
      add_index_title(@query)
      add_context_nav(::Tab::Location::IndexActions.new(
                        query: @query, q_param: q_param(@query),
                        controller: controller
                      ))
      add_sorter(@query, controller.index_sort_options,
                 link_all: link_all_sorts?)
      add_pagination(@pagination_data)
    end

    def link_all_sorts?
      !(params[:id].present? || params[:by].present? ||
        params[:by_user].present?)
    end

    def render_locations
      return unless @locations.any?

      PaginatedResults do
        small(class: "d-block text-right px-3 mb-1") do
          plain(:list_place_names_parenthetical.l)
        end
        render_known_list(@observation_counts)
      end
    end

    def render_known_list(counts)
      ListGroup do |list|
        @locations.each { |loc| render_known_item(list, loc, counts) }
      end
    end

    def render_known_item(list, location, counts)
      list.item(class: "d-flex align-items-start") do
        div(class: "id-badge-col") { IDBadge(object: location, size: :lg) }
        div(class: "flex-grow-1") do
          Link(type: :location, where: location.name.t, location: location)
        end
        div(class: "obs-count-col") { plain("(#{counts[location.id].to_i})") }
      end
    end
  end
end
