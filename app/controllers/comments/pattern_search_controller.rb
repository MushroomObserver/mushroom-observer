# frozen_string_literal: true

# Comments pattern search form.
#
# Route: `new_comment_pattern_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/comments/pattern_search", action: :create }`
module Comments
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
