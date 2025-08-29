# frozen_string_literal: true

# set_review_status
module Names::Descriptions
  class ReviewStatusController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # PUT Callback to let reviewers change review_status of a NameDescription
    # from the show_name page.
    def update
      desc = NameDescription.find(params[:id].to_s)
      desc.update_review_status(params[:value]) if reviewer?
      redirect_to(name_path(desc.name_id))
    end
  end
end
