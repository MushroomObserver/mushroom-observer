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
  before_filter :login_required, :except => [
  ]

  before_filter :disable_link_prefetching, :except => [
  ]

  # Show list of objects user has expressed interest in.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @objects, @object_pages
  def list_interests # :norobots:
    store_location
    @title = :list_interests_title.t
    notifications = Notification.find_all_by_user_id(@user.id).sort do |a,b|
      result = a.flavor.to_s <=> b.flavor.to_s
      result = a.summary.to_s <=> b.summary.to_s if result == 0
      result
    end
    interests = Interest.find_all_by_user_id(@user.id).sort do |a,b|
      result = a.object_type <=> b.object_type
      result = (a.object ? a.object.text_name : '') <=>
               (b.object ? b.object.text_name : '') if result == 0
      result
    end
    @objects = notifications + interests
    @pages = paginate_numbers(:page, 50)
    @pages.num_total = @objects.length
    @objects = @objects[@pages.from..@pages.to]
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
    object = Comment.find_object(type, oid)
    if @user
      interest = Interest.find_by_object_type_and_object_id_and_user_id(type, oid, @user.id)
      if uid && @user.id != uid.to_i
        flash_error(:set_interest_user_mismatch.l)
      elsif !object && state != 0
        flash_error(:set_interest_bad_object.l(:type => type, :id => oid))
      else
        if !interest && state != 0
          interest = Interest.new
          interest.object = object
          interest.user = @user
        end
        if state == 0
          name = object ? object.unique_text_name : '--'
          if !interest
            flash_notice(:set_interest_already_deleted.l(:name => name))
          elsif !interest.destroy
            flash_notice(:set_interest_failure.l(:name => name))
          else
            if interest.state
              flash_notice(:set_interest_success_was_on.l(:name => name))
            else
              flash_notice(:set_interest_success_was_off.l(:name => name))
            end
          end
        elsif interest.state == true && state > 0
          flash_notice(:set_interest_already_on.l(:name => object.unique_text_name))
        elsif interest.state == false && state < 0
          flash_notice(:set_interest_already_off.l(:name => object.unique_text_name))
        else
          interest.state = (state > 0)
          interest.modified = Time.now
          if !interest.save
            flash_notice(:set_interest_failure.l(:name => object.unique_text_name))
          else
            if state > 0
              flash_notice(:set_interest_success_on.l(:name => object.unique_text_name))
            else
              flash_notice(:set_interest_success_off.l(:name => object.unique_text_name))
            end
          end
        end
      end
    end
    if object
      redirect_back_or_default(:controller => object.show_controller,
                               :action => object.show_action, :id => oid,
                               :params => query_params)
    else
      redirect_back_or_default(:controller => 'interest',
                               :action => 'list_interests')
    end
  end
end
