# frozen_string_literal: true

# html used in tabsets
module Tabs
  module LocationsHelper
    # link attribute arrays (each tab returns array)
    def locations_index_tabs(query:)
      [
        new_location_tab,
        map_locations_tab,
        location_countries_tab,
        related_observations_tab(:locations, query)
      ]
    end

    # Composed links because there's interest_icons
    def location_show_tabs
      [
        # observations_at_location_tab(location),
        locations_index_tab,
        new_location_tab
        # edit_location_tab(location)
      ]
      # if in_admin_mode?
      #   links += [
      #     destroy_location_tab(location),
      #     location_reverse_order_tab(location)
      #   ]
      # end
      # links
    end

    def location_show_heading_links(location:)
      links = location_show_tabs(location: location)
      icons = []
      links.each do |link|
        icons << icon_link_to(*link)
      end
      icons
    end

    def new_location_tab
      [:show_location_create.t, add_query_param(new_location_path),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def map_locations_tab
      [:list_place_names_map.t, add_query_param(map_locations_path),
       { class: tab_id(__method__.to_s) }]
    end

    def location_countries_tab
      [:list_countries.t, location_countries_path,
       { class: tab_id(__method__.to_s) }]
    end

    def edit_location_tab(location)
      [:show_location_edit.t,
       add_query_param(edit_location_path(location.id)),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    def destroy_location_tab(location)
      [:show_location_destroy.t, location, { button: :destroy }]
    end

    def location_reverse_order_tab(location)
      [:show_location_reverse.t,
       add_query_param(reverse_name_order_location_path(location.id)),
       { class: tab_id(__method__.to_s), icon: :back }]
    end

    # description tabs:
    def location_show_description_tab(location)
      return unless location&.description

      [:show_name_see_more.l,
       add_query_param(location_description_path(location.description.id)),
       { class: tab_id(__method__.to_s), icon: :list }]
    end

    def location_edit_description_tab(location)
      return unless location&.description

      [:EDIT.l, edit_location_description_path(location.description.id),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    def location_new_description_tab(location)
      [:show_name_create_description.l,
       new_location_description_path(location.id),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def location_version_tabs(location:)
      [location_versions_tab(location)]
    end

    def location_versions_tab(location)
      [:show_location.t(location: location.display_name),
       location_path(location.id),
       { class: tab_id(__method__.to_s) }]
    end

    def locations_index_tab
      [:all_objects.t(type: :location), locations_path,
       { class: tab_id(__method__.to_s) }]
    end

    def observations_at_location_tab(location)
      [show_obs_link_title_with_count(location),
       add_query_param(observations_path(location: location.id)),
       { class: tab_id(__method__.to_s), icon: :observations, show_text: true }]
    end

    def location_map_title(query:)
      if query&.params&.dig(:with_observations)
        :map_locations_title.t(locations: query.title)
      else
        :map_locations_global_map.t
      end
    end

    def location_map_tabs(query:)
      [
        locations_index_tab,
        related_observations_tab(:locations, query),
        related_locations_tab(:locations, query) # index of same locations
      ]
    end

    def location_countries_tabs
      [locations_index_tab]
    end

    # Add some alternate sorting criteria.
    def location_index_sorts(query:)
      rss_log = query&.params&.dig(:by) == :rss_log
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
