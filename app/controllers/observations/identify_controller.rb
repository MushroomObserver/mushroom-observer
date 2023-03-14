# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :pass_query_params
    # around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [:index]

    def index
      @layout = calc_layout_params
      return filtered_index if params[:name].present?

      full_index_or_inherited_query
    end

    private

    def filtered_index
      return unless (name = Name.find(params[:name]))

      query = Query.create_query(Observation, :all, { needs_id_by_taxon: name })

      show_selected_results(query)
    end

    def full_index_or_inherited_query
      old_query = find_or_create_query(:Observation)
      new_query = Query.lookup_and_save(old_query.model, old_query.flavor,
                                        old_query.params.merge(needs_id: true))
      show_selected_results(new_query)
    end

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
