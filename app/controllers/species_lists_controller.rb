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
    build_index_with_query
  end

  private

  # unused now. should be :date, maybe - AN
  def default_sort_order
    ::Query::SpeciesLists.default_order # :title
  end

  def unfiltered_index_opts
    super.merge(query_args: { order_by: :date })
  end

  # Used by ApplicationController to dispatch #index to a private method
  def index_active_params
    [:pattern, :by_user, :project, :by, :q, :id].freeze
  end

  # Display list of selected species_lists, based on current Query.
  # (Linked from show_species_list, next to "prev" and "next".)
  # Passes explicit :by param to affect title (only).
  def sorted_index_opts
    sorted_by = params[:by] || :date
    super.merge(query_args: { order_by: sorted_by })
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
    store_location
    clear_query_in_session
    pass_query_params
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
    init_name_vars_for_create
    init_member_vars_for_create
    init_project_vars_for_create
    init_name_vars_for_clone(params[:clone]) if params[:clone].present?
    @checklist ||= calc_checklist # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def edit
    return unless (@species_list = find_species_list!)

    if check_permission!(@species_list)
      init_name_vars_for_edit(@species_list)
      init_member_vars_for_edit(@species_list)
      init_project_vars_for_edit(@species_list)
      @checklist ||= calc_checklist
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

    if check_permission!(@species_list)
      process_species_list(:update)
    else
      redirect_to(species_list_path(@species_list))
    end
  end

  # Custom endpoint to clear obs from spl
  def clear
    return unless (@species_list = find_species_list!)

    if check_permission!(@species_list)
      @species_list.clear
      flash_notice(:runtime_species_list_clear_success.t)
    end
    redirect_to(species_list_path(@species_list))
  end

  def destroy
    return unless (@species_list = find_species_list!)

    if check_permission!(@species_list)
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
end
