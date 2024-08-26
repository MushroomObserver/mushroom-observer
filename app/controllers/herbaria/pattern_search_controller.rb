# frozen_string_literal: true

# Herbaria pattern search form.
#
# Route: `new_herbarium_pattern_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/herbaria/pattern_search", action: :create }`
module Herbaria
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
