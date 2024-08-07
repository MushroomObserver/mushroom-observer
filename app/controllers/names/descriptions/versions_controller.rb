# frozen_string_literal: true

# show_past_name_description
module Names::Descriptions
  class VersionsController < ApplicationController
    include ::Names::Descriptions::SharedPrivateMethods

    before_action :login_required

    # Show past versions of NameDescription.  Accessible only from
    # show_name_description page.
    def show
      pass_query_params
      store_location
      return unless find_description!

      @name = @description.name
      @description.revert_to(params[:version].to_i)
      @versions = @description.versions
    end
  end
end
