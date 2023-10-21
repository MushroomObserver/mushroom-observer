# frozen_string_literal: true

# reverse_name_order
module Locations
  class ReverseNameOrderController < ApplicationController
    before_action :login_required

    # Callback for :show
    def update
      if (location = Location.safe_find(params[:id].to_s))
        location.name = Location.reverse_name(location.name)
        location.save
      end
      redirect_to(location_path(params[:id].to_s))
    end
  end
end
