# frozen_string_literal: true

# show_past_location
module Locations
  class VersionsController < ApplicationController
    before_action :login_required

    # Show past version of Location.  Accessible only from show_location page.
    def show
      store_location
      pass_query_params
      return unless find_location!

      if params[:version]
        @location.revert_to(params[:version].to_i)
        @versions = @location.versions
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(location_path(@location.id))
      end
    end

    def find_location!
      @location = Location.includes(show_includes).strict_loading.
                  find_by(id: params[:id]) ||
                  flash_error_and_goto_index(Location, params[:id])
    end

    def show_includes
      [:versions]
    end
  end
end
