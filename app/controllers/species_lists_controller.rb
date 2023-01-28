# frozen_string_literal: true

#
#  = Species List Controller
#
#  == Actions
#
#  index::                   Endpoint for all lists
#    (private methods)
#  index_species_list::      List of lists in current query.
#  list_species_lists::      List of lists by date.
#  species_lists_by_title::  List of lists by title.
#  species_lists_by_user::   List of lists created by user.
#  species_list_search::     List of lists matching search.
#
#  show::                    Display notes/etc. and list of species.
#
#  new::                     Form to create new list.
#  edit::                    Form to edit existing list.
#  create::                  Create new list.
#  update::                  Update existing list.
#  clear::                   Remove all observations from list.
#  destroy::                 Destroy list.
#
#  *NOTE*: There is some ambiguity between observations and names that makes
#  this slightly confusing.  The end result of a species list is actually a
#  list of Observation's, not Name's.  However, creation and editing is
#  generally accomplished via Name's alone (although see manage_species_lists
#  for the one exception).  In the end all these Name's cause rudimentary
#  Observation's to spring into existence.
#
class SpeciesListsController < ApplicationController
  before_action :login_required
  before_action :disable_link_prefetching,
                except: [:show, :new, :edit, :create, :update]
  before_action :require_successful_user, only: [:new, :create]

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load synonyms for @deprecated_names in
    # edit_species_list, and I thought it would be possible, but I can't
    # get it to work.  Seems toooo minor to waste any more time on.
    :update
  ]

  @index_subaction_param_keys = [
    :pattern,
    :by_user,
    :for_project,
    :by
  ].freeze

  @index_subaction_dispatch_table = {
    pattern: :species_list_search,
    by_user: :species_lists_by_user,
    for_project: :species_lists_for_project,
    by: :by_title_or_selected_by_query
  }.freeze

  # Disable cop because method definition prevents a
  # Rails/LexicallyScopedActionFilter offense
  # https://docs.rubocop.org/rubocop-rails/cops_rails.html#railslexicallyscopedactionfilter
  def index # rubocop:disable Lint/UselessMethodDefinition
    super
  end

  # def show_species_list
  def show
    store_location
    clear_query_in_session
    pass_query_params
    return unless (@species_list = find_species_list!)

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, SpeciesList, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, SpeciesList, params[:id]) and return
    end

    init_ivars_for_show
  end

  # rubocop:disable Naming/MemoizedInstanceVariableName
  def new
    @species_list = SpeciesList.new
    init_name_vars_for_create
    init_member_vars_for_create
    init_project_vars_for_create
    init_name_vars_for_clone(params[:clone]) if params[:clone].present?
    @checklist ||= calc_checklist
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName

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

  private

  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  def default_index_subaction
    list_species_lists
  end

  # Display list of selected species_lists, based on current Query.
  # (Linked from show_species_list, next to "prev" and "next".)
  def index_species_list
    query = find_or_create_query(:SpeciesList, by: params[:by])
    show_selected_species_lists(query, id: params[:id].to_s,
                                       always_index: true)
  end

  # Display list of all species_lists, sorted by date.
  def list_species_lists
    query = create_query(:SpeciesList, :all, by: :date)
    show_selected_species_lists(query, id: params[:id].to_s, by: params[:by])
  end

  # Display list of user's species_lists, sorted by date.
  def species_lists_by_user
    user = params[:id] ? find_or_goto_index(User, params[:by_user].to_s) : @user
    return unless user

    query = create_query(:SpeciesList, :by_user, user: user)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's attached to a given project.
  def species_lists_for_project
    project = find_or_goto_index(Project, params[:for_project].to_s)
    return unless project

    query = create_query(:SpeciesList, :for_project, project: project)
    show_selected_species_lists(query, always_index: 1)
  end

  # Display list of all species_lists, sorted by title.
  def species_lists_by_title
    query = create_query(:SpeciesList, :all, by: :title)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's whose title, notes, etc. matches a string
  # pattern.
  def species_list_search
    pattern = params[:pattern].to_s
    spl = SpeciesList.safe_find(pattern) if /^\d+$/.match?(pattern)
    if spl
      redirect_to(action: :show, id: spl.id)
    else
      query = create_query(:SpeciesList, :pattern_search, pattern: pattern)
      show_selected_species_lists(query)
    end
  end

  # choose another subaction when params[:by].present?
  def by_title_or_selected_by_query
    params[:by] == "title" ? species_lists_by_title : index_species_list
  end

  # Show selected list of species_lists.
  def show_selected_species_lists(query, args = {})
    @links ||= []
    args = {
      action: :index,
      num_per_page: 20,
      include: [:location, :user],
      letters: "species_lists.title"
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["title",       :sort_by_title.t],
      ["date",        :sort_by_date.t],
      ["user",        :sort_by_user.t],
      ["created_at",  :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t]
    ]

    # Paginate by letter if sorting by user.
    args[:letters] =
      if query.params[:by] == "user" ||
         query.params[:by] == "reverse_user"
        "users.login"
      else
        # Can always paginate by title letter.
        args[:letters] = "species_lists.title"
      end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show
  #
  ##############################################################################

  def init_ivars_for_show
    @canonical_url =
      "#{MO.http_domain}/species_lists/#{@species_list.id}"
    @query = create_query(:Observation, :in_species_list,
                          by: :name, species_list: @species_list)
    store_query_in_session(@query) if params[:set_source].present?
    @query.need_letters = "names.sort_name"
    @pages = paginate_letters(:letter, :page, 100)
    @objects = @query.paginate(@pages, include:
                  [:user, :name, :location, { thumb_image: :image_votes }])
  end

  ##############################################################################
  #
  #  :section: Create and Modify
  #
  ##############################################################################

  include SpeciesLists::SharedPrivateMethods # shared private methods
end
