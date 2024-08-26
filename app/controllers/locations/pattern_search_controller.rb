# frozen_string_literal: true

# Locations pattern search form.
#
# Route: `new_location_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/locations/pattern_search", action: :create }`
module Locations
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
