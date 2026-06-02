# frozen_string_literal: true

module Tabs
  module LocationsHelper
    # The tab definitions migrated to PORO classes under
    # `app/classes/tab/location/*.rb` — 11 single Tab POROs +
    # 7 `Tab::Collection` subclasses (IndexActions, VersionActions,
    # MapActions, CountriesActions, FormNew, FormEdit,
    # ExternalSearch).
    #
    # The methods below remain as thin legacy-shape adapters so
    # existing helper-chain callers (Phlex views, ERB templates,
    # and `Tabs::ObservationsHelper` / `Tabs::NamesHelper` etc.
    # composers) keep working unchanged. Each downstream PR that
    # migrates a caller replaces these calls with direct PORO
    # instantiation; once all callers migrate, the file can be
    # deleted (the `locations_index_sorts` non-tab utility
    # relocates to a new `app/helpers/locations_helper.rb` then).

    # -------- single tabs ----------------------------------------

    def location_reverse_order_tab(location)
      ::Tab::Location::ReverseOrder.new(location: location).to_a
    end

    def location_show_description_tab(location)
      return unless location&.description

      ::Tab::Location::ShowDescription.new(location: location).to_a
    end

    def location_edit_description_tab(location)
      return unless location&.description

      ::Tab::Location::EditDescription.new(location: location).to_a
    end

    def observations_at_location_tab(location)
      ::Tab::Location::ObservationsAt.new(location: location).to_a
    end

    # -------- collections ----------------------------------------

    # Collections delegate to `.map(&:to_a)` to return legacy
    # `[title, url, opts]` array-of-arrays — Tab::Collection.to_a
    # would return Tab::Base instances which the legacy
    # `add_context_nav([...])` path doesn't recognize.

    def locations_index_tabs(query:)
      ::Tab::Location::IndexActions.new(query: query,
                                        q_param: q_param(query),
                                        controller: controller).map(&:to_a)
    end

    def location_version_tabs(location:)
      ::Tab::Location::VersionActions.new(location: location).map(&:to_a)
    end

    def location_map_tabs(query:)
      ::Tab::Location::MapActions.new(query: query,
                                      controller: controller).map(&:to_a)
    end

    def location_countries_tabs
      ::Tab::Location::CountriesActions.new.map(&:to_a)
    end

    def location_form_new_tabs(location:)
      ::Tab::Location::FormNew.new(location: location).map(&:to_a)
    end

    def location_form_edit_tabs(location:)
      ::Tab::Location::FormEdit.new(location: location).map(&:to_a)
    end

    def location_search_tabs(name)
      ::Tab::Location::ExternalSearch.new(name: name).map(&:to_a)
    end

    # -------- non-tab utility (stays a helper) -------------------

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
  end
end
