#
#  Views: ("*" - login required)
#   * list_interests    Show objects user has expressed interest in.
#   * no_interest       Callback from email to express lack of interest.
#   * set_interest      Callback from show_<object> to change interest state.
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
    @title = :list_interests.t
    @interests = Interest.find_by_user(@user)
    @interest_pages, @interests = paginate_array(@interests, 50)
  end

  # Callback to express lack of interest in something.
  # Linked from: email
  # Redirects to main index.
  # Inputs: params[:type], params[:id], params[:user]
  # Outputs: none
  def no_interest
    type = params[:type].to_s
    oid = params[:id].to_i
    uid = params[:user].to_i
    interest = Interest.find_by_object_type_and_object_id_and_user_id(type, oid, uid)
    if @user.id != uid
      flash_error(:no_interest_user_mismatch.l)
    elsif interest
      interest.state = false
      interest.save
      flash_notice(:no_interest_success.l(:name => interest.object.unique_text_name))
    elsif object = Comment.find_object(type, oid)
      interest = Interest.new
      interest.object = object
      interest.user = @user
      interest.state = false
      interest.save
      flash_notice(:no_interest_success.l(:name => object.unique_text_name))
    else
      flash_error(:no_interest_bad_object.l(:type => type, :id => oid))
    end
    redirect_to(:controller => 'observer', :action => 'index')
  end

  # Callback to change interest state in an object.
  # Linked from: show_<object>
  # Redirects to show_<object>
  # Inputs: params[:type], params[:id], params[:state]
  # Outputs: none
  def set_interest
    type  = params[:type].to_s
    id    = params[:id].to_i
    state = params[:state].to_i
    object = Comment.find_object(type, id)
    if @user
      interest = Interest.find_by_object_type_and_object_id_and_user_id(type, id, @user.id)
      if !object
        flash_error(:no_interest_bad_object.l(:type => type, :id => id))
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
                             :action => object.show_action, :id => id)
  end
end
