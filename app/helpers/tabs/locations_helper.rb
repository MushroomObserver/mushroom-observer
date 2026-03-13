# frozen_string_literal: true

# html used in tabsets
module Tabs
  module LocationsHelper
    # link attribute arrays (each tab returns array)
    def locations_index_tabs(query:)
      [
        new_location_tab,
        map_locations_tab(query),
        location_countries_tab,
        related_observations_tab(:Location, query)
      ]
    end

    def new_location_tab
      InternalLink::Model.new(
        :show_location_create.t, Location,
        new_location_path,
        html_options: { icon: :add }
      ).tab
    end

    def map_locations_tab(query)
      InternalLink.new(
        :list_place_names_map.t, add_q_param(map_locations_path, query)
      ).tab
    end

    def location_countries_tab
      InternalLink.new(
        :list_countries.t, location_countries_path
      ).tab
    end

    def edit_location_tab(location)
      InternalLink::Model.new(
        :show_location_edit.t, location,
        edit_location_path(location.id),
        html_options: { icon: :edit }
      ).tab
    end

    # Dead code
    # def destroy_location_tab(location)
    #   InternalLink::Model.new(
    #     :show_location_destroy.t, location, location,
    #     html_options: { button: :destroy }
    #   ).tab
    # end

    def location_reverse_order_tab(location)
      InternalLink::Model.new(
        :show_location_reverse.t, location,
        reverse_name_order_location_path(location.id),
        html_options: { icon: :back }
      ).tab
    end

    # description tabs:
    def location_show_description_tab(location)
      return unless location&.description

      InternalLink::Model.new(
        :show_name_see_more.l, location,
        location_description_path(location.description.id),
        html_options: { icon: :list }
      ).tab
    end

    def location_edit_description_tab(location)
      return unless location&.description

      InternalLink::Model.new(
        :EDIT.l, location,
        edit_location_description_path(location.description.id),
        html_options: { icon: :edit }
      ).tab
    end

    def location_new_description_tab(location)
      InternalLink::Model.new(
        :show_name_create_description.l, location,
        new_location_description_path(location.id),
        html_options: { icon: :add }
      ).tab
    end

    def location_version_tabs(location:)
      [location_versions_tab(location)]
    end

    def location_versions_tab(location)
      InternalLink::Model.new(
        :show_location.t(location: location.display_name), location,
        location_path(location.id),
        alt_title: :show_object.t(TYPE: Location)
      ).tab
    end

    def locations_index_tab
      InternalLink::Model.new(
        :all_objects.t(type: :location), Location,
        locations_path
      ).tab
    end

    def observations_at_location_tab(location)
      query = Query.lookup(:Observation, locations: location.id)

      InternalLink::Model.new(
        show_obs_link_title_with_count(location), location,
        add_q_param(observations_path, query),
        alt_title: :show_location_observations.t,
        html_options: { icon: :observations, show_text: true }
      ).tab
    end

    def location_map_tabs(query:)
      [
        locations_index_tab,
        related_observations_tab(:Location, query),
        related_locations_tab(:Location, query) # index of same locations
      ]
    end

    def location_countries_tabs
      [locations_index_tab]
    end

    # Add some alternate sorting criteria.
    def locations_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t],
        ["box_area", :sort_by_box_area.t]
      ]
    end

    # link attribute arrays
    def location_form_new_tabs(location:)
      tabs = [locations_index_tab]
      tabs += location_search_tabs(location.name) if location&.name
      tabs
    end

    def location_form_edit_tabs(location:)
      tabs = [
        locations_index_tab,
        object_return_tab(location)
      ]
      tabs += location_search_tabs(location.name) if location&.name
      tabs
    end

    # Array of link attribute arrays to searches on external sites;
    # Shown on create/edit location pages
    def location_search_tabs(name)
      search_string = name.gsub(" Co.", " County").gsub(", USA", "").
                      tr(" ", "+").gsub(",", "%2C")
      external_search_urls.each_with_object([]) do |site, link_array|
        link_array << search_tab_for(site.first, search_string)
      end
    end
  end
end
