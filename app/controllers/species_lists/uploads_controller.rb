# frozen_string_literal: true

module SpeciesLists
  class UploadsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
  end
end
