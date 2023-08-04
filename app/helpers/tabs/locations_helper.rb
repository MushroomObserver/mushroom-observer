# frozen_string_literal: true

# html used in tabsets
module Tabs
  module LocationsHelper
    # link attribute arrays (coerced_query_link returns array)
    def locations_index_tabs(query)
      tabs = [
        [:show_location_create.t, add_query_param(new_location_path),
         { id: "new_location_link" }],
        [:list_place_names_map.t, add_query_param(map_locations_path),
         { id: "map_locations_link" }],
        [:list_countries.t, location_countries_path,
         { id: "location_countries_link" }]
      ]

      # Add "show observations" link if this query can be coerced into an
      # observation query. (coerced_query_link returns array)
      tabs << coerced_query_link(query, Observation)
    end

    # Composed links because there's interest_icons
    def location_show_tabs(location)
      tabs = [
        link_with_query(show_obs_link_title_with_count(location),
                        observations_path(location: location.id)),
        link_to(:all_objects.t(type: :location), locations_path),
        link_with_query(:show_location_create.t, new_location_path),
        link_with_query(:show_location_edit.t,
                        edit_location_path(location.id))
      ]
      if in_admin_mode?
        tabs += [
          destroy_button(name: :show_location_destroy.t, target: location),
          link_with_query(:show_location_reverse.t,
                          location_reverse_name_order_path(location.id))
        ]
      end
      tabs << draw_interest_icons(location)
    end

    # link attribute arrays
    def location_form_new_links(location)
      tabs = [
        locations_index_link
      ]
      tabs += location_search_links(location.name)
      tabs
    end

    def location_form_edit_links(location)
      tabs = [
        locations_index_link,
        [:cancel_and_show.t(type: :location),
         add_query_param(location.show_link_args),
         { id: "location_link" }]
      ]
      tabs += location_search_links(location.name)
      tabs
    end

    def locations_index_link
      [:all_objects.t(type: :location), locations_path,
       { id: "locations_index_link" }]
    end

    # Dictionary of urls for searches on external sites
    LOCATION_SEARCH_URLS = {
      Google_Maps: "https://maps.google.com/maps?q=",
      Google_Search: "https://www.google.com/search?q=",
      Wikipedia: "https://en.wikipedia.org/w/index.php?search="
    }.freeze

    # Array of link attribute arrays to searches on external sites;
    # Shown on create/edit location pages
    def location_search_links(name)
      search_string = name.gsub(" Co.", " County").gsub(", USA", "").
                      tr(" ", "+").gsub(",", "%2C")
      LOCATION_SEARCH_URLS.each_with_object([]) do |site, link_array|
        link_array << search_link_to(site.first, search_string)
      end
    end

    # link attribute arrays
    def search_link_to(site_symbol, search_string)
      return unless (url = LOCATION_SEARCH_URLS[site_symbol])

      [site_symbol.to_s.titlecase, "#{url}#{search_string}",
       { id: "search_link_to_#{site_symbol}_#{search_string}" }]
    end
  end
end
