# frozen_string_literal: true

# set_review_status
module Names::Descriptions
  class ReviewStatusController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # Callback to let reviewers change the review status of a Name from the
    # show_name page.
    def set_review_status
      pass_query_params
      id = params[:id].to_s
      desc = NameDescription.find(id)
      desc.update_review_status(params[:value]) if reviewer?
      redirect_with_query(action: :show_name, id: desc.name_id)
    end
  end
end
