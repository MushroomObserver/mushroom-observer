# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def index
      build_index_with_query
    end

    private

    def controller_model_name
      "Observation"
    end

    # override the default? maybe no longer necessary
    def unfiltered_index_opts
      super.merge(query_args: { needs_naming: true, by: :rss_log })
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

      query = create_query(:Observation,
                           needs_naming: true, by: :rss_log, in_clade: term)
      [query, {}]
    end

    def region(term)
      query = create_query(:Observation,
                           needs_naming: true, by: :rss_log, in_region: term)
      [query, {}]
    end

    # def user_filter(term)
    #   query = create_query(:Observation,
    #                        needs_naming: true, by: :rss_log,
    #                        by_user: params[:user])
    #   [query, {}]
    # end

    def index_display_opts(opts, _query)
      { matrix: true, cache: true,
        include: observation_identify_index_includes }.merge(opts)
    end

    def observation_identify_index_includes
      [observation_matrix_box_image_includes,
       :location,
       { name: :synonym },
       { namings: [:name, :votes] },
       :rss_log, :user]
    end
  end
end
