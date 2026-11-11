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

      render_locations
    end

    private

    def register_chrome
      container_class(:wide)
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

      PaginatedResults { render_location_rows }
    end

    def render_location_rows
      ListGroup do |list|
        render_header_row(list)
        @locations.each { |location| render_location_row(list, location) }
      end
    end

    def render_header_row(list)
      list.item(class: "d-flex align-items-start") do
        div(class: "id-badge-col") { b { plain(:mo_id.ti) } }
        div(class: "flex-grow-1") { b { plain(:location.ti) } }
        div(class: "obs-count-col") { b { plain(:sort_by_observations.t) } }
      end
    end

    def render_location_row(list, location)
      list.item(class: "d-flex align-items-start") do
        div(class: "id-badge-col") { IDBadge(object: location, size: :lg) }
        div(class: "flex-grow-1") do
          Link(type: :location, where: location.name.t, location: location)
        end
        div(class: "obs-count-col") do
          CountBadge(count: @observation_counts[location.id].to_i)
        end
      end
    end
  end
end
