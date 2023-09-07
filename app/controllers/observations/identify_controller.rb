# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

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

    def unfiltered_index
      query = create_query(:Observation, :needs_id, {})

      show_selected_results(query)
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

      query = create_query(:Observation, :needs_id, { in_clade: term })

      show_selected_results(query)
    end

    def region_filter(term)
      query = create_query(:Observation, :needs_id, { in_region: term })

      show_selected_results(query)
    end

    # def user_filter(term)
    #   query = create_query(:Observation, :needs_id, { by_user: term })

    #   show_selected_results(query)
    # end

    # TODO: Allow show_index_of_objects to `render` rather than `redirect`,
    # or better yet `respond_to do |format|` and write index.js.erb templates
    # to just render the #results div.
    def show_selected_results(query)
      args = { matrix: true,
               include: [:location, :user, :rss_log,
                         { name: :synonym },
                         { namings: :name },
                         { images: [:image_votes, :license, :projects, :user] },
                         { thumb_image: :image_votes }] }

      show_index_of_objects(query, args)
    end
  end
end
