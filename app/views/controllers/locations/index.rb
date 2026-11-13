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

      PaginatedResults { render_location_table }
    end

    def render_location_table
      Table(@locations) do |t|
        t.column(:mo_id.ti) { |loc| IDBadge(object: loc, size: :lg) }
        t.column(:location.ti) do |loc|
          Link(type: :location, where: loc.name.t, location: loc)
        end
        t.column(:sort_by_observations.t, align: :right) do |loc|
          CountBadge(count: @observation_counts[loc.id].to_i)
        end
      end
    end
  end
end
