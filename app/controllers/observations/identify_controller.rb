# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # TODO: use dispatcher, add q, id (order is not adjustable)
    # refactor to flat params `clade` and `region`
    def index
      @layout = calc_layout_params
      # first deal with filters, or clear filter
      return unfiltered_index if params[:commit] == :CLEAR.l

      if (type = params.dig(:filter, :type))
        return filtered_index(type.to_sym)
      end

      unfiltered_index
    end

    private

    def q_args
      [:Observation, :needs_naming]
    end

    def q_kwargs
      { by: :rss_log }
    end

    def unfiltered_index
      query = create_query(*q_args, q_kwargs)

      show_selected(query)
    end

    # need both a :type and a :term
    def filtered_index(type)
      return unless (term = params.dig(:filter, :term).strip)

      case type
      when :clade
        clade_filter(term)
      when :region
        region_filter(term)
        # when :user
        #   user_filter(term)
      end
    end

    # Some inefficiency here comes from having to parse the name from a string.
    # TODO: Write a filtered select/autocomplete that passes the name_id?
    def clade_filter(term)
      # return unless (clade = Name.find_by(text_name: term))

      query = create_query(*q_args, q_kwargs.merge({ in_clade: term }))

      show_selected(query)
    end

    def region_filter(term)
      query = create_query(*q_args, q_kwargs.merge({ in_region: term }))

      show_selected(query)
    end

    # def user_filter(term)
    #   query = create_query(*q_args, q_kwargs.merge({ by_user: term }))

    #   show_selected(query)
    # end

    def show_selected(query, args = {})
      show_index_of_objects(query, index_display_args(args, query))
    end

    def index_display_args(args, _query)
      {
        matrix: true,
        cache: true,
        include: observation_identify_index_includes
      }.merge(args)
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
