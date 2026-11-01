# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required

    # `needs_naming` always applies on this page, filtered or not --
    # forcing it here (rather than merging it in a subaction) means
    # every request recognizes a filter param, so build_index_with_query
    # always takes the generic filtered path, not unfiltered_index.
    def index
      params[:needs_naming] ||= "1"
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
