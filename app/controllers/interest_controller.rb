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
  before_action :login_required, except: []

  before_action :disable_link_prefetching, except: []

  # Show list of objects user has expressed interest in.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @targets, @target_pages
  def list_interests # :norobots:
    store_location
    @title = :list_interests_title.t
    # notifications = Notification.find_all_by_user_id(@user.id).sort do |a,b|
    notifications = Notification.where(user_id: @user.id).sort do |a, b|
      result = a.flavor.to_s <=> b.flavor.to_s
      result = a.summary.to_s <=> b.summary.to_s if result.zero?
      result
    end
    # interests = Interest.find_all_by_user_id(@user.id).sort do |a,b|
    interests = Interest.where(user_id: @user.id).sort do |a, b|
      result = a.target_type <=> b.target_type
      result = (a.target ? a.target.text_name : "") <=>
               (b.target ? b.target.text_name : "") if result.zero?
      result
    end
    @targets = notifications + interests
    @pages = paginate_numbers(:page, 50)
    @pages.num_total = @targets.length
    @targets = @targets[@pages.from..@pages.to]
  end

  # Callback to change interest state in an object.
  # Linked from: show_<object> and emails
  # Redirects back (falls back on show_<object>)
  # Inputs: params[:type], params[:id], params[:state], params[:user]
  # Outputs: none
  def set_interest # :norobots:
    pass_query_params
    type   = params[:type].to_s
    oid    = params[:id].to_i
    state  = params[:state].to_i
    uid    = params[:user]
    target = Comment.find_object(type, oid)
    if @user
      interest = Interest.find_by_target_type_and_target_id_and_user_id(type, oid, @user.id)
      if uid && @user.id != uid.to_i
        flash_error(:set_interest_user_mismatch.l)
      elsif !target && state != 0
        flash_error(:set_interest_bad_object.l(type: type, id: oid))
      else
        if !interest && state != 0
          interest = Interest.new
          interest.target = target
          interest.user = @user
        end
        if state.zero?
          name = target ? target.unique_text_name : "--"
          if !interest
            flash_notice(:set_interest_already_deleted.l(name: name))
          elsif !interest.destroy
            flash_notice(:set_interest_failure.l(name: name))
          else
            if interest.state
              flash_notice(:set_interest_success_was_on.l(name: name))
            else
              flash_notice(:set_interest_success_was_off.l(name: name))
            end
          end
        elsif interest.state == true && state.positive?
          flash_notice(:set_interest_already_on.l(name: target.unique_text_name))
        elsif interest.state == false && state.negative?
          flash_notice(:set_interest_already_off.l(name: target.unique_text_name))
        else
          interest.state = (state.positive?)
          interest.updated_at = Time.now
          if !interest.save
            flash_notice(:set_interest_failure.l(name: target.unique_text_name))
          else
            if state.positive?
              flash_notice(:set_interest_success_on.l(name: target.unique_text_name))
            else
              flash_notice(:set_interest_success_off.l(name: target.unique_text_name))
            end
          end
        end
      end
    end
    if target
      redirect_back_or_default(
        add_query_param(controller: target.show_controller,
                        action: target.show_action, id: oid)
      )
    else
      redirect_back_or_default(controller: "interest",
                               action: "list_interests")
    end
  end

  def destroy_notification
    pass_query_params
    Notification.find(params[:id].to_i).destroy
    redirect_with_query(action: "list_interests")
  end
end
