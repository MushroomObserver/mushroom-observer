# frozen_string_literal: true

module Views::Controllers::Locations
  # Index page — paginated list of known locations on the left and
  # unmatched `Observation#where` strings on the right. Used by
  # `LocationsController#index` and its filtered_index dispatch.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :locations, _Array(::Location)
    prop :pagination_data, ::PaginationData
    prop :undef_pages, ::PaginationData
    # `[Observation, count]` pairs — one per unique unmatched
    # location string on the current page.
    prop :undef_data, _Array(_Tuple(::Observation, ::Integer))
    # `{ location_id => observation_count }`, built in the controller.
    prop :observation_counts, _Hash(::Integer, ::Integer),
         default: -> { {} }
    prop :default_orders, _Boolean, default: false
    def view_template
      register_chrome

      div(class: "row mt-3") do
        div(class: "col-md-7") { render_known(@observation_counts) }
        div(class: "col-md-5") { render_undefined }
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

    def render_section_heading(label_key, order_key, css:)
      div(class: css) do
        plain(label_key.l)
        if @default_orders
          whitespace
          plain(order_key.l)
        end
      end
    end

    def render_known(counts)
      return unless @pagination_data.any? && @locations.any?

      render_section_heading(:list_place_names_known,
                             :list_place_names_known_order,
                             css: "h4 px-3 mb-0")
      render(::Components::ContentPadded.new) do
        small { plain(:list_place_names_parenthetical.l) }
      end
      render(::Components::PaginatedResults.new) { render_known_list(counts) }
    end

    def render_known_list(counts)
      render(::Components::ListGroup::Base.new) do |list|
        @locations.each { |loc| render_known_item(list, loc, counts) }
      end
    end

    def render_known_item(list, location, counts)
      list.item do
        render(::Components::Link::Location.new(
                 where: location.name.t, location: location,
                 count: counts[location.id].to_i
               ))
      end
    end

    def render_undefined
      return unless @undef_pages.any? && @undef_data.any?

      render_section_heading(:list_place_names_undef,
                             :list_place_names_undef_order,
                             css: "h4 px-3")
      div(id: "locations_undefined") { render_undefined_list }
    end

    def render_undefined_list
      render(::Components::ListGroup::Base.new) do |list|
        @undef_data.each do |obs, count|
          render_undefined_item(list, obs, count)
        end
      end
    end

    def render_undefined_item(list, obs, count)
      location_name = obs[:where]
      list.item do
        render(::Components::Link::Location.new(
                 where: location_name, count: count
               ))
        render(::Components::Link::Icon.new(
                 content: :list_place_names_merge.l,
                 path: matching_locations_for_observations_path(
                   where: location_name
                 ),
                 icon: :merge, show_text: false
               ))
      end
    end
  end
end
