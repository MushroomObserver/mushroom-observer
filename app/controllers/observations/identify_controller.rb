# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :pass_query_params
    # around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [:index]

    def index
      @layout = calc_layout_params

      # first deal with filters, or clear filter
      if params[:commit] == "Clear"
        return clear_filter
      elsif (type = params.dig(:filter, :type).to_sym)
        return filtered_index(type)
      end

      full_index_or_inherited_query
    end

    private

    def clear_filter
      query = create_query(:Observation, :all, { needs_id: true })

      show_selected_results(query)
    end

    # need both a :type and a :term
    def filtered_index(type)
      return unless (term = params.dig(:filter, :term).strip)

      case type
      when :name
        name_filter(term)
        # when :location
        #   location_filter
        # when :user
        #   user_filter
      end
    end

    def name_filter(term)
      return unless (filter = Name.find_by(text_name: term))

      # Nimmo note: 2023-03-14 to be researched: This obviously sends, and
      # `Query::ObservationAll` expects, a full `Name` instance, but somehow
      # the flavor parsing method `needs_id` only receives the name ID.
      query = create_query(:Observation, :all, { needs_id_by_taxon: filter })

      show_selected_results(query)
    end

    def full_index_or_inherited_query
      old_query = find_or_create_query(:Observation)
      new_query = Query.lookup_and_save(old_query.model, old_query.flavor,
                                        old_query.params.merge(needs_id: true))
      show_selected_results(new_query)
    end

    # TODO: Allow show_index_of_objects to `render` rather than `redirect`,
    # or better yet `respond_to do |format|` and write index.js.erb templates
    # to just render the #results div.
    def show_selected_results(query)
      show_index_of_objects(query,
                            { matrix: true,
                              include: [:location, :user, :rss_log,
                                        { name: :synonym },
                                        { namings: :name },
                                        { thumb_image: :image_votes }] })
    end
  end
end
