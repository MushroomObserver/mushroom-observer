# frozen_string_literal: true

# SpeciesLists pattern search form.
#
# Route: `new_species_list_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/species_lists/pattern_search", action: :create }`
module SpeciesLists
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
