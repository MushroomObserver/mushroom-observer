# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required

    def index
      build_index_with_query
    end

    def render_index_view
      render(Views::Controllers::Observations::Identify::Index.new(
               query: @query,
               pagination_data: @pagination_data,
               objects: @objects,
               user: @user
             ))
    end

    def controller_model_name
      "Observation"
    end

    # `MatrixTable` always renders in `identify: true` mode here, which
    # bypasses the fragment cache — the per-user vote selector and
    # footer chrome can't be cached. The pre-check in
    # `Indexes#objects_with_only_needed_eager_loads` must agree,
    # otherwise the controller would skip eager-loading rows it
    # thinks are cache hits and then render uncached boxes → N+1.
    def matrix_caches_in_this_request?
      false
    end

    private

    # override the default? maybe no longer necessary
    def unfiltered_index_opts
      super.merge(query_args: { needs_naming: true, order_by: :rss_log })
    end

    def default_sort_order
      :rss_log
    end

    def index_active_params
      [:identify_filter, :q, :id].freeze
    end

    # Dispatches to Observation.identify_filter (Observation::Scopes),
    # which picks clade or region based on identify_filter[type] --
    # the single swappable autocompleter submits both under one field
    # pair. `needs_naming` always applies on this page regardless of
    # the optional clade/region sub-filter, so it's merged in here
    # rather than coming from the URL.
    def identify_filter
      create_query_from_url_params(
        :Observation, params.merge(needs_naming: true)
      )
    end

    def index_display_opts(opts, _query)
      { matrix: true, cache: true,
        include: observation_identify_index_includes }.merge(opts)
    end

    # `matrix_box_includes` + identify-specific preloads: name
    # synonyms (for name comparison), per-user observation_views,
    # and `naming.name` (the identify queue's naming column).
    # `:name`, `:namings`, and `:projects` from the shared tree
    # are merged by Rails' includes hash-merge.
    def observation_identify_index_includes
      Observation.matrix_box_includes +
        [:observation_views, { name: :synonym }, { namings: :name }]
    end
  end
end
