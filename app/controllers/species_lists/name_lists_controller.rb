# frozen_string_literal: true

module SpeciesLists
  class NameListsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :require_successful_user
  end
end
