# frozen_string_literal: true

#  == ENDPOINT FOR TESTING
#  test_index::                         Show distribution map.

module Names
  class TestIndexController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # Used to test pagination.
    def index
      query = find_query(:Name)
      raise("Missing query: #{params[:q]}") unless query

      if params[:test_anchor]
        @test_pagination_args = { anchor: params[:test_anchor] }
      end
      show_selected_names(query, num_per_page: params[:num_per_page].to_i)
    end
  end
end
