# frozen_string_literal: true

# reverse_name_order
module Locations
  class ReverseNameOrderController < ApplicationController
    before_action :login_required

    # Callback for :show
    def update
      if (loc = Location.safe_find(params[:id].to_s))
        loc.name, loc.scientific_name = loc.scientific_name, loc.name
        loc.save
      end
      redirect_to(location_path(params[:id].to_s))
    end
  end
end
