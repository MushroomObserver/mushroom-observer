# frozen_string_literal: true

# Herbarium record pattern search form.
#
# Route: `new_herbarium_record_pattern_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/herbarium_records/pattern_search", action: :create }`
module HerbariumRecords
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
