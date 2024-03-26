# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :store_location
    before_action :pass_query_params

    def new
    end

    def create
    end
  end
end
