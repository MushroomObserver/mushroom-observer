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
    # footer chrome can't be cached. The pre-check on
    # `object_fragment_exist?` must agree, otherwise the controller
    # would skip eager-loading rows it thinks are cache hits and then
    # render uncached boxes → N+1.
    def matrix_caches_in_this_request?
      false
    end

    private

    # override the default? maybe no longer necessary
    def unfiltered_index_opts
      super.merge(query_args: { needs_naming: @user, order_by: :rss_log })
    end

    def default_sort_order
      :rss_log
    end

    def index_active_params
      [:filter, :q, :id].freeze
    end

    # Ideally the filter form should pass the clade/region params with separate
    # terms, so we can build the query by multiple flat params as expected.
    # However, this form uses a single field with swapping autocompleter;
    # the form scope is :filter and the field name is always :term.
    # Currently params needs both a :filter[:type] and a filter[:term] to work.
    def filter
      return unless (type = params.dig(:filter, :type).to_sym)
      return unless (term = params.dig(:filter, :term).strip)

      case type
      when :clade
        clade(term)
      when :region
        region(term)
        # when :user
        #   user(term)
      end
    end

    # Some inefficiency here comes from having to parse the name from a string.
    # Check if the autocompleters return a name_id or location_id.
    def clade(term)
      # return unless (clade = Name.find_by(text_name: term))

      query = create_query(:Observation, needs_naming: @user, clade: term,
                                         order_by: :rss_log)
      [query, {}]
    end

    def region(term)
      query = create_query(:Observation, needs_naming: @user, region: term,
                                         order_by: :rss_log)
      [query, {}]
    end

    # def user_filter(term)
    #   query = create_query(:Observation, needs_naming: @user, by_users: term,
    #                                      order_by: :rss_log)
    #   [query, {}]
    # end

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
