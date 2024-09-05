# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_name_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/pattern_search", action: :create }`
module Names
  class PatternSearchController < ApplicationController
    include ::PatternSearchable

    before_action :login_required

    def new
      @fields = name_search_params
    end

    def create
      @pattern = human_formatted_pattern_search_string
      redirect_to(controller: "/names", action: :index, pattern: @pattern)
    end

    private

    def permitted_search_params
      params.permit(name_search_params)
    end

    def name_search_params
      PatternSearch::Name.params.keys + [:pattern]
    end
  end
end
