# frozen_string_literal: true

# Projects pattern search form.
#
# Route: `new_project_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/projects/pattern_search", action: :create }`
module Projects
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
