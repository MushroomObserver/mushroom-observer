#
#  Views: ("*" - login required)
#   * list_interests    Show objects user has expressed interest in.
#   * set_interest      Callback to change interest state.
#
################################################################################

class InterestController < ApplicationController
  before_filter :login_required, :except => [
  ]

  # Show list of objects user has expressed interest in.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @interests, @interest_pages
  def list_interests
    store_location
    @title = :list_interests_title.t
    @interests = Interest.find_all_by_user_id(@user.id)
    @interest_pages, @interests = paginate_array(@interests, 50)
  end

  # Callback to change interest state in an object.
  # Linked from: show_<object> and emails
  # Redirects back (falls back on show_<object>)
  # Inputs: params[:type], params[:id], params[:state], params[:user]
  # Outputs: none
  def set_interest
    type  = params[:type].to_s
    oid   = params[:id].to_i
    state = params[:state].to_i
    uid   = params[:user]
    object = Comment.find_object(type, oid)
    if @user
      interest = Interest.find_by_object_type_and_object_id_and_user_id(type, oid, @user.id)
      if uid && @user.id != uid.to_i
        flash_error(:set_interest_user_mismatch.l)
      elsif !object
        flash_error(:set_interest_bad_object.l(:type => type, :id => oid))
      else
        if !interest && state != 0
          interest = Interest.new
          interest.object = object
          interest.user = @user
        end
        if state == 0
          if !interest
            flash_notice(:set_interest_already_deleted.l(:name => object.unique_text_name))
          elsif !interest.destroy
            flash_notice(:set_interest_failure.l(:name => object.unique_text_name))
          elsif interest.state
            flash_notice(:set_interest_success_was_on.l(:name => object.unique_text_name))
          else
            flash_notice(:set_interest_success_was_off.l(:name => object.unique_text_name))
          end
        elsif interest.state == true && state > 0
          flash_notice(:set_interest_already_on.l(:name => object.unique_text_name))
        elsif interest.state == false && state < 0
          flash_notice(:set_interest_already_off.l(:name => object.unique_text_name))
        else
          interest.state = (state > 0)
          if !interest.save
            flash_notice(:set_interest_failure.l(:name => object.unique_text_name))
          elsif state > 0
            flash_notice(:set_interest_success_on.l(:name => object.unique_text_name))
          else
            flash_notice(:set_interest_success_off.l(:name => object.unique_text_name))
          end
        end
      end
    end
    redirect_back_or_default(:controller => object.show_controller,
                             :action => object.show_action, :id => oid)
  end
end
