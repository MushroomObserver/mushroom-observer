# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController

  ##############################################################################
  #
  #  :section: Indexes and Searche
  #
  ##############################################################################

  # Display list of selected species_lists, based on current Query.
  # (Linked from show_species_list, next to "prev" and "next".)
  def index_species_list
    query = find_or_create_query(:SpeciesList, by: params[:by])
    show_selected_species_lists(query, id: params[:id].to_s, always_index: true)
  end

  # Display list of all species_lists, sorted by date.
  def index
    query = create_query(:SpeciesList, :all, by: :date)
    show_selected_species_lists(query, id: params[:id].to_s, by: params[:by])
  end

  alias_method :list_species_lists, :index

  # Display list of user's species_lists, sorted by date.
  def species_lists_by_user
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:SpeciesList, :by_user, user: user)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's attached to a given project.
  def species_lists_for_project
    project = find_or_goto_index(Project, params[:id].to_s)
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
    @species_list = SpeciesList.safe_find(pattern) if /^\d+$/.match?(pattern)
    if @species_list
      redirect_to species_list_path(@species_list.id)
    else
      query = create_query(:SpeciesList, :pattern_search, pattern: pattern)
      show_selected_species_lists(query)
    end
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

end
