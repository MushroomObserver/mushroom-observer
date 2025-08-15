# frozen_string_literal: true

# Names search form and help.
#
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/search", action: :create }`
module Names
  class SearchController < ApplicationController
    include ::Searchable

    before_action :login_required
  end
end
