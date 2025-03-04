# frozen_string_literal: true

#
#  = Interests Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index::
#  set_interest::
#  create::
#  update::
#  destroy::
#
################################################################################

class InterestsController < ApplicationController
  before_action :login_required
  before_action :pass_query_params, except: [:index]

  # Show list of objects user has expressed interest in.
  # Linked from: left-hand panel
  # Inputs: params[:page], params[:type]
  # Outputs: @interests, @types, @pages, @selected_type
  def index
    store_location
    @container = :wide
    @interests = find_relevant_interests
    @types = interest_types(@interests)
    @selected_type = params[:type].to_s
    @interests = filter_interests_by_type(@interests, @selected_type) \
      if @selected_type.present?
    @pages = paginate_interests!
  end

  private

  def find_relevant_interests
    interests = Interest.for_user(@user).includes(:target)
    eager_load_targets(interests)
    interests.sort do |a, b|
      result = a.target_type <=> b.target_type
      if result.zero?
        result = (a.target ? a.target.text_name : "") <=>
                 (b.target ? b.target.text_name : "")
      end
      result
    end
  end

  def eager_load_targets(interests)
    # Props to this blog for teaching how to eager-load polymorphic relations!
    # https://thepaulo.medium.com/eager-loading-polymorphic-associations-in-ruby-on-rails-155a356c39d7
    %w[NameTracker Observation].each do |type|
      ActiveRecord::Associations::Preloader.new(
        records: interests.select { |i| i.target_type == type },
        associations: { target: [:name] }
      )
    end
  end

  def interest_types(interests)
    interests.map(&:target_type).uniq.sort
  end

  def filter_interests_by_type(interests, type)
    interests.select { |i| i.target_type.to_s == type.to_s }
  end

  def paginate_interests!
    pages = paginate_numbers(:page, 100)
    pages.num_total = @interests.length
    @interests = @interests[pages.from..pages.to]
    pages
  end

  public

  # GET Callback to change interest state in an object.
  # Linked from: show_<object> and emails
  # This is a GET action that updates the db, for one-click updates via email.
  # It calls :create, :update or :destroy.
  # Redirects back (falls back on show_<object>) in all cases
  # Inputs: params[:type], params[:id], params[:state], params[:user]
  # Outputs: none
  def set_interest
    target_type = params[:type].to_s
    target_id   = params[:id].to_i
    @target = find_target(target_type, target_id)
    @state = params[:state].to_i

    unless check_params_or_flash_errors!(target_type, target_id)
      redirect_to_target_or_list_interests and return
    end

    @interest = find_or_create_interest
    set_interest_state_for_target_and_redirect
  end

  private

  def check_params_or_flash_errors!(target_type, target_id)
    if (user_id = params[:user]) && @user.id != user_id.to_i
      flash_error(:set_interest_user_mismatch.l)
      return false
    elsif !@target && @state != 0
      flash_error(:set_interest_bad_object.l(type: target_type, id: target_id))
      return false
    end
    true
  end

  # For set_interest: handles destroy, create, update, and no change
  def set_interest_state_for_target_and_redirect
    if @state.zero?
      name = @target ? @target.unique_text_name : "--"
      destroy_interest_plus_tracker_and_flash_notice(name)
    elsif @interest.state == true && @state.positive?
      flash_notice(
        :set_interest_already_on.l(name: @target.unique_text_name)
      )
    elsif @interest.state == false && @state.negative?
      flash_notice(
        :set_interest_already_off.l(name: @target.unique_text_name)
      )
    else
      update_interest_and_flash_notice
    end
    redirect_to_target_or_list_interests
  end

  # Used by set_interest, create, and update
  def update_interest_and_flash_notice
    @interest.state = @state.positive?
    @interest.updated_at = Time.zone.now
    if !@interest.save
      flash_notice(:set_interest_failure.l(name: @target.unique_text_name))
    elsif @state.positive?
      flash_notice(
        :set_interest_success_on.l(name: @target.unique_text_name)
      )
    else
      flash_notice(
        :set_interest_success_off.l(name: @target.unique_text_name)
      )
    end
  end

  def find_target(target_type, target_id)
    AbstractModel.find_object(target_type, target_id)
  end

  # Convenience for "set_interests"
  def find_or_create_interest
    interest = find_interest
    return interest if interest

    create_interest
  end

  # For :update and :destroy
  # NOTE: AR stores polymorphic target_type as the string "ClassName"!
  # find_by(target_type: @target.type_tag) (:name_tracker) does not work when
  # target_type is multi-word, PascalCase, for whatever reason.
  def find_interest
    Interest.find_by(
      target_type: @target.class.to_s, target_id: @target.id, user_id: @user.id
    )
  end

  # For :create
  def create_interest
    interest = Interest.new
    interest.target = @target
    interest.user = @user
    interest
  end

  public

  def create
    target_type = params[:type].to_s
    target_id   = params[:id].to_i
    @target = find_target(target_type, target_id)
    @state = params[:state].to_i

    return redirect_to_target_or_list_interests unless
      check_params_or_flash_errors!(target_type, target_id)

    @interest = create_interest

    update_interest_and_flash_notice
    redirect_to_target_or_list_interests
  end

  def update
    target_type = params[:type].to_s
    target_id   = params[:id].to_i
    @target = find_target(target_type, target_id)
    @state = params[:state].to_i

    return redirect_to_target_or_list_interests unless
      check_params_or_flash_errors!(target_type, target_id)

    @interest = find_interest
    return interest unless !interest && @state != 0

    update_interest_and_flash_notice
    redirect_to_target_or_list_interests
  end

  def destroy
    target_type = params[:type].to_s
    target_id   = params[:id].to_i
    @target = find_target(target_type, target_id)

    return redirect_to_target_or_list_interests unless
      check_params_or_flash_errors!(target_type, target_id)

    @interest = find_interest
    name = @target ? @target.unique_text_name : "--"

    destroy_interest_plus_tracker_and_flash_notice(name)
    redirect_to_target_or_list_interests
  end

  private

  def destroy_interest_plus_tracker_and_flash_notice(name)
    if !@interest
      flash_notice(:set_interest_already_deleted.l(name: name))
    elsif !@interest.destroy
      flash_notice(:set_interest_failure.l(name: name))
    else
      @target.destroy if @interest.target_type == "NameTracker"
      if @interest.state
        flash_notice(:set_interest_success_was_on.l(name: name))
      else
        flash_notice(:set_interest_success_was_off.l(name: name))
      end
    end
  end

  # All CRUD actions end with this
  def redirect_to_target_or_list_interests
    if !@target || @target.type_tag == :name_tracker
      return redirect_back_or_default(interests_path)
    end

    redirect_back_or_default(
      add_query_param(controller: @target.show_controller,
                      action: @target.show_action, id: @target.id)
    )
  end
end
