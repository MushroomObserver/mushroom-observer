# frozen_string_literal: true

# Users pattern search form.
#
# Route: `new_user_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/users/pattern_search", action: :create }`
module Users
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
