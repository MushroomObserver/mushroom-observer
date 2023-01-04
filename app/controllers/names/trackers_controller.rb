# frozen_string_literal: true

#  == NAME TRACKERS
#  email_tracking::
#  approve_tracker::

module Names
  class TrackersController < ApplicationController
    # Form accessible from show_name that lets a user setup a tracker
    # with notifications for a name.
    def email_tracking
      pass_query_params
      name_id = params[:id].to_s
      @name = find_or_goto_index(Name, name_id)
      return unless @name

      @name_tracker = NameTracker.find_by(name_id: name_id, user_id: @user.id)
      if request.method == "POST"
        submit_tracking_form(name_id)
      else
        initialize_tracking_form
      end
    end

          private

    def initialize_tracking_form
      if @name_tracker
        @note_template = @name_tracker.note_template
        @name_tracker.note_template_enabled = @note_template.present?
        @interest = Interest.find_by(target: @name_tracker)
      else
        @note_template = :email_tracking_note_template.l(
          species_name: @name.real_text_name,
          mailing_address: @user.mailing_address_for_tracking_template,
          users_name: @user.legal_name
        )
      end
    end

    def submit_tracking_form(name_id)
      case params[:commit]
      when :ENABLE.l, :UPDATE.l
        create_or_update_name_tracker_and_interest(name_id)
      when :DISABLE.l
        destroy_name_tracker_interest_and_flash
      end
      redirect_with_query(action: "show_name", id: name_id)
    end

    def create_or_update_name_tracker_and_interest(name_id)
      @note_template = param_lookup([:name_tracker, :note_template])
      note_template_enabled = \
        param_lookup([:name_tracker, :note_template_enabled]) == "1"
      @note_template = nil if @note_template.blank? || !note_template_enabled
      if @name_tracker.nil?
        create_name_tracker_interest_and_flash(name_id)
      else
        update_name_tracker_interest_and_flash
      end
      notify_admins_of_name_tracker(@name_tracker)
      @name_tracker.save
      @interest.save
    end

    def create_name_tracker_interest_and_flash(name_id)
      @name_tracker = NameTracker.new(user: @user,
                                      name_id: name_id,
                                      note_template: @note_template,
                                      approved: false)
      @interest = Interest.new(user: @user, target: @name_tracker, state: 1)
      flash_notice(:email_tracking_now_tracking.t(name: @name.display_name))
    end

    def update_name_tracker_interest_and_flash
      @name_tracker.note_template = @note_template
      @interest = Interest.find_by(target: @name_tracker)
      flash_notice(:email_tracking_updated_messages.t)
    end

    def destroy_name_tracker_interest_and_flash
      @interest = Interest.find_by(target: @name_tracker)
      @name_tracker.destroy
      @interest.destroy
      flash_notice(
        :email_tracking_no_longer_tracking.t(name: @name.display_name)
      )
    end

    # disable cop because method is clear and
    # there's no easy way to reduce ABC count of <2, 20, 3> 20.32/20
    def notify_admins_of_name_tracker(name_tracker) # rubocop:disable Metrics/AbcSize
      return if name_tracker.note_template.blank?
      # Only give notifications when users turn on the template function,
      # not when they edit the template after its already been approved.
      return unless name_tracker.new_record? ||
                    name_tracker.note_template_before_last_save.blank?

      user = name_tracker.user
      name = name_tracker.name
      WebmasterMailer.build(
        sender_email: user.email,
        subject: "New Name Tracker with Template",
        content: "User: ##{user.id} / #{user.login} / #{user.email}\n" \
                 "Name: ##{name.id} / #{name.search_name}\n" \
                 "Note: [[#{name_tracker.note_template}]]\n\n" \
                 "#{MO.http_domain}/name/approve_tracker/#{name_tracker.id}"
      ).deliver_now

      # Let the user know that the note_template feature requires approval.
      flash_notice(:email_tracking_awaiting_approval.t)
    end

          public

    def approve_tracker
      return unless (tracker = find_or_goto_index(NameTracker, params[:id]))

      approve_tracker_if_everything_okay(tracker)
      redirect_to("/")
    end

          private

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
