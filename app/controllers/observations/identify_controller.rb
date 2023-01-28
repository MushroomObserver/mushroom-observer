# frozen_string_literal: true

module Observations
  class IdentifyController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def index
      @layout = calc_layout_params
      # @pages = paginate_numbers(:page, @layout["count"])
      @objects = Observation.needs_identification(@user).
                 order(created_at: :desc).limit(@layout["count"] * 2)
    end
  end
end
