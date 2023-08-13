# frozen_string_literal: true

# html used in tabsets
module Tabs
  module LocationsHelper
    # link attribute arrays (coerced_query_link returns array)
    def locations_index_links(query:)
      [
        new_location_link,
        map_locations_link,
        location_countries_link,
        coerced_observation_query_link(query)
      ]
    end

    # Composed links because there's interest_icons
    def location_show_links(location:)
      links = [
        observations_at_location_link(location),
        locations_index_link,
        new_location_link,
        edit_location_link(location)
      ]
      if in_admin_mode?
        links += [
          destroy_location_link(location),
          location_reverse_order_link(location)
        ]
      end
      links
    end

    def new_location_link
      [:show_location_create.t, add_query_param(new_location_path),
       { class: __method__.to_s }]
    end

    def map_locations_link
      [:list_place_names_map.t, add_query_param(map_locations_path),
       { class: __method__.to_s }]
    end

    def location_countries_link
      [:list_countries.t, location_countries_path,
       { class: __method__.to_s }]
    end

    def edit_location_link(location)
      [:show_location_edit.t,
       add_query_param(edit_location_path(location.id)),
       { class: __method__.to_s }]
    end

    def destroy_location_link(location)
      [:show_location_destroy.t, location, { button: :destroy }]
    end

    def location_reverse_order_link(location)
      [:show_location_reverse.t,
       add_query_param(location_reverse_name_order_path(location.id)),
       { class: __method__.to_s }]
    end

    def location_version_links(location:)
      [location_versions_link(location)]
    end

    def location_versions_link(location)
      [:show_location.t(location: location.display_name),
       location_path(location.id),
       { class: __method__.to_s }]
    end

    def locations_index_link
      [:all_objects.t(type: :location), locations_path,
       { class: __method__.to_s }]
    end

    def observations_at_location_link(location)
      [show_obs_link_title_with_count(location),
       add_query_param(observations_path(location: location.id)),
       { class: __method__.to_s }]
    end

    def location_map_links(query:)
      [
        locations_index_link,
        coerced_observation_query_link(query),
        coerced_location_query_link(query)
      ]
    end

    def location_countries_links
      [locations_index_link]
    end

    # link attribute arrays
    def location_form_new_links(location:)
      tabs = [locations_index_link]
      tabs += location_search_links(location.name)
      tabs
    end

    def location_form_edit_links(location:)
      tabs = [
        locations_index_link,
        object_return_link(location)
      ]
      tabs += location_search_links(location.name)
      tabs
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

    # these are from the observations form
    def define_location_link(query)
      [:list_observations_location_define.l,
       add_query_param(new_location_path(
                         where: query.params[:user_where]
                       )),
       { class: __method__.to_s }]
    end

    def merge_locations_link(query)
      [:list_observations_location_merge.l,
       add_query_param(location_merges_form_path(
                         where: query.params[:user_where]
                       )),
       { class: __method__.to_s }]
    end
  end
end
