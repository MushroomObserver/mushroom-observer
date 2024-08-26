# frozen_string_literal: true

# Observations pattern search form.
#
# Route: `new_observation_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/observations/pattern_search", action: :create }`
module Observations
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
