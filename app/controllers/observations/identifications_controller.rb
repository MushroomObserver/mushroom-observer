# frozen_string_literal: true

module Observations
  class IdentificationsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def index
      @query = Observation.needs_identification
    end
  end
end
