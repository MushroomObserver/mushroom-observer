# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :pass_query_params

    def index
      @layout = calc_layout_params
      old_query = find_or_create_query(:Observation)
      new_query = Query.lookup_and_save(old_query.model, old_query.flavor,
                                        old_query.params.merge(needs_id: true))
      show_index_of_objects(new_query, { matrix: true })
    end
  end
end
