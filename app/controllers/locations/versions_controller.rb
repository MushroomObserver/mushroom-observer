# frozen_string_literal: true

# show_past_location
module Locations
  class VersionsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # Show past version of Location.  Accessible only from show_location page.
    def show
      store_location
      return unless find_location!

      if params[:version]
        @location.revert_to(params[:version].to_i)
        @versions = @location.versions
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(location_path(@location.id))
      end
    end

    def show_includes
      [:user, :versions]
    end

    private

    def find_location!
      @location = Location.show_includes.safe_find(params[:id]) ||
                  flash_error_and_goto_index(Location, params[:id])
    end
  end
end
