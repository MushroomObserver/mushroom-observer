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

    def approve_tracker_if_everything_okay(tracker)
      return flash_warning(:permission_denied.t) unless @user.admin
      return flash_warning("Already approved.") if tracker.approved
      return flash_warning("Not a spammer.") if tracker.note_template.blank?

      tracker.update(approved: true)
      flash_notice("Name stalker approved.")
      notify_user_name_tracking_approved(tracker)
    end

    def notify_user_name_tracking_approved(tracker)
      subject = :email_subject_name_tracker_approval.l(
        name: tracker.name.display_name
      )
      content = :email_name_tracker_body.l(
        user: tracker.user.legal_name,
        name: tracker.name.display_name,
        link: "#{MO.http_domain}/interests/?type=NameTracker"
      )
      QueuedEmail::Approval.find_or_create_email(tracker.user, subject, content)
    end
  end
end
