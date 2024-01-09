# frozen_string_literal: true

# show_past_location_description
module Locations::Descriptions
  class VersionsController < ApplicationController
    include ::Locations::Descriptions::SharedPrivateMethods

    before_action :login_required

    # Show past version of LocationDescription.  Accessible only from
    # show_location_description page.
    def show
      store_location
      pass_query_params
      return unless find_description!

      @location = @description.location
      @description.revert_to(params[:version].to_i)
      @versions = @description.versions
    end
  end
end
