# frozen_string_literal: true

# show_past_name_description
module Names::Descriptions
  class VersionsController < ApplicationController
    before_action :login_required

    # Show past versions of NameDescription.  Accessible only from
    # show_name_description page.
    def show
      pass_query_params
      store_location
      @description = find_or_goto_index(NameDescription, params[:id].to_s)
      return unless @description

      @name = @description.name
      @description.revert_to(params[:version].to_i)
    end
  end
end
