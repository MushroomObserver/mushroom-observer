# frozen_string_literal: true

# show_past_location
module Locations
  class VersionsController < ApplicationController
    before_action :login_required

    # Show past version of Location.  Accessible only from show_location page.
    def show
      store_location
      pass_query_params
      @location = find_or_goto_index(Location, params[:id].to_s)
      return unless @location

      if params[:version]
        @location.revert_to(params[:version].to_i)
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(location_path(@location.id))
      end
    end
  end
end
