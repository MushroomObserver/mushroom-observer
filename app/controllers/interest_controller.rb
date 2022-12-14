# frozen_string_literal: true

#
#  = Interest Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  list_interests::
#  set_interest::
#
################################################################################

class InterestController < ApplicationController
  before_action :login_required
  before_action :disable_link_prefetching

  # Show list of objects user has expressed interest in.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @targets, @target_pages
  def list_interests
    store_location
    @title = :list_interests_title.t
    notifications = find_relevant_notifications
    interests = find_relevant_interests
    @targets = notifications + interests

    @pages = paginate_numbers(:page, 50)
    @pages.num_total = @targets.length
    @targets = @targets[@pages.from..@pages.to]
  end

  private

  def find_relevant_notifications
    Notification.for_user(@user).sort do |a, b|
      result = a.flavor.to_s <=> b.flavor.to_s
      result = a.summary.to_s <=> b.summary.to_s if result.zero?
      result
    end
  end

  def find_relevant_interests
    Interest.for_user(@user).sort do |a, b|
      result = a.target_type <=> b.target_type
      if result.zero?
        result = (a.target ? a.target.text_name : "") <=>
                 (b.target ? b.target.text_name : "")
      end
      result
    end
  end

  public

  # Callback to change interest state in an object.
  # Linked from: show_<object> and emails
  # Redirects back (falls back on show_<object>)
  # Inputs: params[:type], params[:id], params[:state], params[:user]
  # Outputs: none
  def set_interest # rubocop:disable Metrics/AbcSize
    pass_query_params
    type   = params[:type].to_s
    oid    = params[:id].to_i
    state  = params[:state].to_i
    uid    = params[:user]
    target = Comment.find_object(type, oid)
    return unless @user

    interest = Interest.find_by(
      target_type: type, target_id: oid, user_id: @user.id
    )
    if uid && @user.id != uid.to_i
      flash_error(:set_interest_user_mismatch.l)
    elsif !target && state != 0
      flash_error(:set_interest_bad_object.l(type: type, id: oid))
    else
      set_interest_state_for_target(interest, state, target)
    end
    redirect_to_target_or_interests(target)
  end

  private

  def redirect_to_target_or_interests(target)
    unless target
      redirect_back_or_default(controller: "interest",
                               action: "list_interests")
    end

    redirect_back_or_default(
      add_query_param(controller: target.show_controller,
                      action: target.show_action, id: oid)
    )
  end

  # rubocop:disable Metrics/AbcSize
  def set_interest_state_for_target(interest, state, target)
    if !interest && state != 0
      interest = Interest.new
      interest.target = target
      interest.user = @user
    end
    if state.zero?
      remove_interest_from_target_and_flash_notice(interest, target)
    elsif interest.state == true && state.positive?
      flash_notice(
        :set_interest_already_on.l(name: target.unique_text_name)
      )
    elsif interest.state == false && state.negative?
      flash_notice(
        :set_interest_already_off.l(name: target.unique_text_name)
      )
    else
      set_new_interest_state_and_flash_notice(interest, state, target)
    end
  end
  # rubocop:enable Metrics/AbcSize

  def remove_interest_from_target_and_flash_notice(interest, target)
    name = target ? target.unique_text_name : "--"
    if !interest
      flash_notice(:set_interest_already_deleted.l(name: name))
    elsif !interest.destroy
      flash_notice(:set_interest_failure.l(name: name))
    elsif interest.state
      flash_notice(:set_interest_success_was_on.l(name: name))
    else
      flash_notice(:set_interest_success_was_off.l(name: name))
    end
  end

  def set_new_interest_state_and_flash_notice(interest, state, target)
    interest.state = state.positive?
    interest.updated_at = Time.zone.now
    if !interest.save
      flash_notice(:set_interest_failure.l(name: target.unique_text_name))
    elsif state.positive?
      flash_notice(
        :set_interest_success_on.l(name: target.unique_text_name)
      )
    else
      flash_notice(
        :set_interest_success_off.l(name: target.unique_text_name)
      )
    end
  end

  public

  def destroy_notification
    pass_query_params
    Notification.find(params[:id].to_i).destroy
    redirect_with_query(action: "list_interests")
  end
end
