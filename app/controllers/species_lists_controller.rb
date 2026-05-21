# frozen_string_literal: true

#  *NOTE*: There is some ambiguity between observations and names that makes
#  this slightly confusing.  The end result of a species_list is actually a
#  list of Observation's, not Name's.  However, creation and editing is
#  generally accomplished via Name's alone (although see manage_species_lists
#  for the one exception).  In the end all these Name's cause rudimentary
#  Observation's to spring into existence.
#
class SpeciesListsController < ApplicationController
  before_action :login_required
  before_action :require_successful_user, only: [:new, :create]
  before_action :store_location, only: [:show]
  # Bullet wants us to eager load synonyms for @deprecated_names in
  # edit_species_list, and I thought it would be possible, but I can't
  # get it to work.  Seems toooo minor to waste any more time on.
  # Also, as of 20231212, it wants a cached column for Observation.name,
  # but this is not as simple as an AR default column_cache because count
  # needs to be recalculated whenever an observation's consensus name
  # changes, not just on create or destroy of the Observation.name.
  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    :create, :update
  ]

  ##############################################################################
  # INDEX
  #
  def index
    set_project_ivar
    build_index_with_query
  end

  private

  # unused now. should be :date, maybe - AN
  def default_sort_order
    ::Query::SpeciesLists.default_order # :date
  end

  def unfiltered_index_opts
    super.merge(query_args: { order_by: :date })
  end

  # Used by ApplicationController to dispatch #index to a private method
  def index_active_params
    [:pattern, :by_user, :project, :by, :q, :id].freeze
  end

  # Display list of user's species_lists, sorted by date.
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: species_lists_path
    )
    return unless user

    query = create_query(:SpeciesList, by_users: user, order_by: :date)
    [query, {}]
  end

  # Display list of SpeciesList's attached to a given project.
  def project
    project = find_or_goto_index(Project, params[:project].to_s)
    return unless project

    query = create_query(:SpeciesList, projects: project)
    @project = project
    [query, { always_index: true }]
  end

  def index_display_opts(opts, query)
    opts = {
      num_per_page: 20,
      include: [:location, :user]
    }.merge(opts)

    if %w[date created modified].include?(query.params[:order_by]) ||
       query.params[:order_by].blank?
      return opts
    end

    # Paginate by letter if sorting by anything else.
    opts[:letters] = true
    opts
  end

  public

  ##############################################################################

  def show
    return unless (@species_list = find_species_list!)

    set_project_ivar
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, SpeciesList, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, SpeciesList, params[:id]) and return
    end

    init_ivars_for_show
  end

  def new
    @species_list = SpeciesList.new
    init_project_vars_for_create
    init_list_for_clone(params[:clone]) if params[:clone].present?
  end

  def edit
    return unless (@species_list = find_species_list!)

    if permission!(@species_list)
      @place_name = @species_list.place_name
      init_project_vars_for_edit(@species_list)
    else
      redirect_to(species_list_path(@species_list))
    end
  end

  def create
    @species_list = SpeciesList.new
    process_species_list(:create)
  end

  def update
    return unless (@species_list = find_species_list!)

    if permission!(@species_list)
      process_species_list(:update)
    else
      redirect_to(species_list_path(@species_list))
    end
  end

  # Custom endpoint to clear obs from spl
  def clear
    return unless (@species_list = find_species_list!)

    if permission!(@species_list)
      @species_list.clear
      flash_notice(:runtime_species_list_clear_success.t)
    end
    redirect_to(species_list_path(@species_list))
  end

  def destroy
    return unless (@species_list = find_species_list!)

    if permission!(@species_list)
      @species_list.destroy
      id = params[:id].to_s
      flash_notice(:runtime_species_list_destroy_success.t(id: id))
      redirect_to(species_lists_path)
    else
      redirect_to(species_list_path(@species_list))
    end
  end

  ##############################################################################
  #
  #  :section: Show
  #
  ##############################################################################

  def init_ivars_for_show # rubocop:disable Metrics/AbcSize
    @canonical_url = "#{MO.http_domain}/species_lists/#{@species_list.id}"
    @query = create_query(
      :Observation, order_by: :name, species_lists: @species_list
    )

    # See documentation on the 'How to Use' page to understand this feature.
    store_query_in_session(@query) if params[:set_source].present?

    @query.need_letters = true
    @pagination_data = letter_pagination_data(:letter, :page, 100)
    update_stored_query(@query) if @pagination_data.any? # also stores query
    @objects = @query.paginate(
      @pagination_data,
      include: [:user, :name, :location, { thumb_image: :image_votes }]
    )
    # Save a lookup in comments_for_object
    @comments = @species_list.comments&.sort_by(&:created_at)&.reverse
    # Matches for the list-search autocompleter
    @object_names = @species_list.observations.joins(:name).
                    select(Name[:text_name], Name[:id]).distinct.
                    order(Name[:text_name])
  end

  ##############################################################################
  #
  #  :section: Create and Modify
  #
  ##############################################################################

  include SpeciesLists::SharedPrivateMethods # shared private methods

  private

  def process_species_list(create_or_update)
    # Update the timestamps/user/when/where/title/notes fields.
    init_basic_species_list_fields(create_or_update)

    # Validate place name.
    validate_place_name

    # so we can redirect to show_species_list (or chain to create location).
    redirected = false
    if @dubious_where_reasons == []
      if @species_list.save
        check_for_clone
        redirected = update_redirect_and_flash_notices(create_or_update)
      else
        flash_object_errors(@species_list)
      end
    end
    return if redirected

    init_project_vars_for_reload(@species_list)
    render(create_or_update == :create ? :new : :edit)
  end

  def validate_place_name
    if Location.is_unknown?(@species_list.place_name) ||
       @species_list.place_name.blank?
      @species_list.location = Location.unknown
      @species_list.where = nil
    end

    @place_name = @species_list.place_name
    @dubious_where_reasons = []
    # `approved_where` lives under the species_list namespace (post-Phlex)
    # so the dubious-confirmation flag travels with the form's other
    # fields as a regular form param. The pre-Phlex form passed this
    # value as a top-level URL query param; the new SpeciesListForm
    # posts it as a hidden field via `hidden_field(:approved_where, ...)`.
    approved_where = params.dig(:species_list, :approved_where)
    unless (@place_name != approved_where) &&
           @species_list.location_id.nil?
      return
    end

    db_name = Location.user_format(@user, @place_name)
    @dubious_where_reasons = Location.dubious_name?(db_name, true)
  end

  def check_for_clone
    clone = SpeciesList.safe_find(params[:clone_id])
    return if clone.blank?

    clone.observations.each do |obs|
      @species_list.observations << obs
    end
  end

  def init_basic_species_list_fields(create_or_update)
    now = Time.zone.now
    @species_list.created_at = now if create_or_update == :create
    @species_list.updated_at = now
    @species_list.user = @user
    apply_species_list_params
  end

  def apply_species_list_params
    if params[:species_list]
      args = params[:species_list]
      @species_list.attributes = args.permit(permitted_species_list_args)
    end
    @species_list.title = @species_list.title.to_s.strip_squeeze
  end

  def update_redirect_and_flash_notices(create_or_update)
    log_and_flash_notices(create_or_update)
    update_projects(@species_list, params.dig(:species_list, :project_ids))

    if @species_list.location_id.nil?
      redirect_to(new_location_path(where: @place_name,
                                    set_species_list: @species_list.id))
    else
      redirect_to(species_list_path(@species_list))
    end
    true
  end

  def log_and_flash_notices(create_or_update)
    id = @species_list.id
    if create_or_update == :create
      @species_list.log(:log_species_list_created)
      flash_notice(:runtime_species_list_create_success.t(id: id))
    else
      @species_list.log(:log_species_list_updated)
      flash_notice(:runtime_species_list_edit_success.t(id: id))
    end
  end

  # `submitted_ids` is the `species_list[project_ids][]` array from
  # the form: the projects the user wants the SL attached to. Only
  # projects in `@user.projects_member` are toggled — non-member
  # projects the SL belongs to are preserved by omission (disabled
  # checkboxes don't submit, and the iteration excludes them anyway).
  def update_projects(spl, submitted_ids)
    return unless submitted_ids

    desired = submitted_ids.compact_blank.map(&:to_i)
    any_changes = false
    Project.where(id: @user.projects_member.map(&:id)).
      includes(:species_lists).find_each do |project|
      before = spl.projects.include?(project)
      after = desired.include?(project.id)
      next if before == after

      change_project_species_lists(
        project: project, spl: spl, change: (after ? :add : :remove)
      )
      any_changes = true
    end

    flash_notice(:species_list_show_manage_observations_too.t) if any_changes
  end

  def init_list_for_clone(clone_id)
    return unless (clone = SpeciesList.safe_find(clone_id))

    @clone_id = clone_id
    @species_list.when = clone.when
    @species_list.place_name = clone.place_name
    @species_list.location = clone.location
    @species_list.title = clone.title
  end

  def change_project_species_lists(project:, spl:, change: :add)
    if change == :add
      project.add_species_list(spl)
      flash_notice(:attached_to_project.t(object: :species_list,
                                          project: project.title))
    else
      project.remove_species_list(spl)
      flash_notice(:removed_from_project.t(object: :species_list,
                                           project: project.title))
    end
  end

  def permitted_species_list_args
    ["when(1i)", "when(2i)", "when(3i)", :place_name, :title, :notes]
  end
end
