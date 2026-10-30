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
  before_action :store_location, only: [:index]

  # Display order for the type-filter pills -- not alphabetical, the
  # most-common target types come first. Anything not listed here
  # (location_description, name_description, name_tracker) sorts
  # after, alphabetically.
  TYPE_FILTER_ORDER = %w[name observation project species_list
                         location].freeze

  # Display order for the state-filter pills.
  STATE_FILTER_ORDER = [:watching, :ignoring].freeze

  def index
    build_index_with_query
  end

  def render_index_view
    render(Views::Controllers::Interests::Index.new(
             interests: @objects, types: @types,
             selected_type: @selected_type,
             states: @states, selected_state: @selected_state,
             pagination_data: @pagination_data, query: @query
           ))
  end

  private

  # Interests are private -- `by_users` is forced to the current
  # user's id on every dispatch branch, not read from a request
  # param. `type`/`state` also need normalizing to the lowercase tag
  # form `Query::Interests` expects -- the structural-enum validator
  # does no case folding. Stripping the originals first (rather than
  # just not forcing a replacement) means a blank or malformed value
  # degrades to "no filter" instead of a validation error.
  def create_query_from_url_params(model_symbol, raw_params)
    forced = { by_users: [@user.id],
               type: normalized_type_or_state(raw_params[:type]),
               state: normalized_type_or_state(raw_params[:state]) }
    super(model_symbol,
         raw_params.except(:type, :state).merge(forced.compact))
  end

  # `type`/`state` are single-select -- a hand-crafted URL could
  # submit an empty string or an Array; take the first value and
  # drop anything that doesn't normalize to a non-blank tag.
  def normalized_type_or_state(value)
    value = value.first if value.is_a?(Array)
    value.to_s.underscore.presence
  end

  # `by_users` is always present (forced above), so it must not by
  # itself count as "a filter is active" -- otherwise every request
  # would route through create_query_from_url_params, which has no
  # find_or_create_query session-merge step `sorted_index` relies on.
  def other_filter_param_present?
    filter_params = controller_query_class.recognized_params -
                    INDEX_BASIC_PARAMS - [:pattern, :by_users, :by_user]
    filter_params.any? { |p| params[p].present? }
  end

  def unfiltered_index_opts
    super.deep_merge(query_args: { by_users: [@user.id] })
  end

  def sorted_index_opts
    super.deep_merge(query_args: { by_users: [@user.id] })
  end

  # `opts` wins where it sets something unique (e.g. a pattern-search
  # redirect flag); `always_index: true` must win regardless, since
  # Interest has no show page to redirect a single result to.
  def index_display_opts(opts, _query)
    opts.merge(num_per_page: 100, always_index: true,
               include: Interest.index_includes_tree)
  end

  # Hook runs before template displayed. Must return query. Derives
  # the filter-pill ivars from the resolved query instead of raw
  # params, matching whichever dispatch branch built it. `state` is a
  # scalar attr (not array-wrapped like `types`), so it comes back as
  # a bare Symbol, not an Array.
  def filtered_index_final_hook(query, _display_opts)
    @selected_type = query.params[:types]&.first&.to_s
    @types = available_types
    @selected_state = query.params[:state]&.to_s
    @states = available_states(@selected_type)
    query
  end

  def available_types
    Interest.for_user(@user).distinct.pluck(:target_type).map(&:underscore).
      sort_by { |t| [TYPE_FILTER_ORDER.index(t) || TYPE_FILTER_ORDER.size, t] }
  end

  def available_states(type)
    interests = Interest.for_user(@user)
    interests = interests.types(type) if type.present?
    present = interests.distinct.pluck(:state).map(&:to_sym)
    STATE_FILTER_ORDER & present
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
    elsif @interest.watching? && @state.positive?
      flash_notice(
        :set_interest_already_on.l(name: @target.unique_text_name)
      )
    elsif @interest.ignoring? && @state.negative?
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
    return redirect_to_target_or_list_interests if !@interest &&
                                                   @state.zero?

    @interest ||= create_interest
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
      if @interest.watching?
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

    redirect_back_or_default(@target.show_link_args)
  end
end
