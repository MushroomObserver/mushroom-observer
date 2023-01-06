# frozen_string_literal: true

# approve_name
module Names::Trackers
  class ApproveController < ApplicationController
    before_action :login_required

    # Endpoint for admins to approve a tracker.
    def new
      return unless (tracker = find_or_goto_index(NameTracker, params[:id]))

      approve_tracker_if_everything_okay(tracker)
      redirect_to("/")
    end
  end
end
