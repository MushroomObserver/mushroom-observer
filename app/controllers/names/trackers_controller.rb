# frozen_string_literal: true

#  == NAME TRACKERS
#  email_tracking::
#  approve_tracker::
module Names
  class TrackersController < ApplicationController
    before_action :pass_query_params
    before_action :login_required

    # Form accessible from show_name that lets a user setup a tracker
    # with notifications for a name.
    def new
      return unless find_name!

      initialize_tracking_form_new
    end

    def create
      return unless find_name!

      submit_tracking_form_create
    end

    def edit
      return unless find_name!

      find_name_tracker
      initialize_tracking_form_edit
    end

    def update
      return unless find_name!

      find_name_tracker
      submit_tracking_form_udpate
    end

    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id].to_s)
    end

    def find_name_tracker
      @name_tracker = NameTracker.find_by(name_id: @name.id, user_id: @user.id)
    end

    def initialize_tracking_form_new
      @note_template = :email_tracking_note_template.l(
        species_name: @name.real_text_name,
        mailing_address: @user.mailing_address_for_tracking_template,
        users_name: @user.legal_name
      )
    end

    def initialize_tracking_form_edit
      @note_template = @name_tracker.note_template
      @name_tracker.note_template_enabled = @note_template.present?
      @interest = Interest.find_by(target: @name_tracker)
    end

    def submit_tracking_form_create
      create_or_update_name_tracker_and_interest(@name.id)
      redirect_to(name_path(@name.id, q: get_query_param))
    end

    def submit_tracking_form_udpate
      case params[:commit]
      when :UPDATE.l
        create_or_update_name_tracker_and_interest(@name.id)
      when :DISABLE.l
        destroy_name_tracker_interest_and_flash
      end
      redirect_to(name_path(@name.id, q: get_query_param))
    end

    def create_or_update_name_tracker_and_interest(name_id)
      @note_template = params.dig(:name_tracker, :note_template)
      note_template_enabled =
        params.dig(:name_tracker, :note_template_enabled) == "1"
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
    def notify_admins_of_name_tracker(name_tracker)
      return if name_tracker.note_template.blank?
      # Only give notifications when users turn on the template function,
      # not when they edit the template after its already been approved.
      return unless name_tracker.new_record? ||
                    name_tracker.note_template_before_last_save.blank?

      user = name_tracker.user
      name = name_tracker.name
      QueuedEmail::Webmaster.create_email(
        sender_email: user.email,
        subject: "New Name Tracker with Template",
        content: "User: ##{user.id} / #{user.login} / #{user.email}\n" \
                 "Name: ##{name.id} / #{name.search_name}\n" \
                 "Note: [[#{name_tracker.note_template}]]\n\n" \
                 "#{MO.http_domain}/names/trackers/#{name_tracker.id}/approve"
      )

      # Let the user know that the note_template feature requires approval.
      flash_notice(:email_tracking_awaiting_approval.t)
    end
  end
end
