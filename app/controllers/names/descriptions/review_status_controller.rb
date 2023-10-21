# frozen_string_literal: true

# set_review_status
module Names::Descriptions
  class ReviewStatusController < ApplicationController
    before_action :login_required

    # PUT Callback to let reviewers change review_status of a NameDescription
    # from the show_name page.
    def update
      pass_query_params
      id = params[:id].to_s
      desc = NameDescription.find(id)
      desc.update_review_status(params[:value]) if reviewer?
      redirect_with_query(name_path(desc.name_id))
    end
  end
end
