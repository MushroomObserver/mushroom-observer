# frozen_string_literal: true

# see app/controllers/names_controller.rb
class NamesController

  ##############################################################################
  #
  #  :section: Show Name
  #
  ##############################################################################

  # Show a Name, one of its Name::Description's, associated taxa, and a bunch of
  # relevant Observations.
  def show
    pass_query_params
    store_location
    clear_query_in_session

    # Load Name and Name::Description along with a bunch of associated objects.
    name_id = params[:id].to_s
    @name = find_or_goto_index(Name, name_id)
    return unless @name

    update_view_stats(@name)

    # Tell robots the proper URL to use to index this content.
    @canonical_url = "#{MO.http_domain}/names/#{@name.id}"

    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @name.descriptions.none? { |d| d.belongs_to_project?(project) }
    end

    # Create query for immediate children.
    @children_query = create_query(:Name, :all,
                                   names: @name.id,
                                   include_immediate_subtaxa: true,
                                   exclude_original_names: true)
    if @name.at_or_below_genus?
      @subtaxa_query = create_query(:Observation, :all,
                                    names: @name.id,
                                    include_subtaxa: true,
                                    exclude_original_names: true,
                                    by: :confidence)
    end

    # Create search queries for observation lists.
    @consensus_query = create_query(:Observation, :all,
                                    names: @name.id, by: :confidence)

    @obs_with_images_query = create_query(:Observation, :all,
                                          names: @name.id,
                                          has_images: true,
                                          by: :confidence)

    # Determine which queries actually have results and instantiate the ones
    # we'll use.
    @best_description = @name.best_brief_description
    @first_four       = @obs_with_images_query.results(limit: 4)
    @first_child      = @children_query.results(limit: 1).first
    @first_consensus  = @consensus_query.results(limit: 1).first
    @has_subtaxa      = @subtaxa_query.select_count if @subtaxa_query
  end

  alias_method :show_name, :show

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name
    pass_query_params
    store_location
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name

    @name.revert_to(params[:version].to_i)
    @correct_spelling = ""
    return unless @name.is_misspelling?

    # Old correct spellings could have gotten merged with something else
    # and no longer exist.
    @correct_spelling = Name.connection.select_value %(
      SELECT display_name FROM names WHERE id = #{@name.correct_spelling_id}
    )
  end

  # Go to next name: redirects to show_name.
  def show_next
    redirect_to_next_object(:next, Name, params[:id].to_s)
  end

  alias_method :next_name, :show_next

  # Go to previous name: redirects to show_name.
  def show_prev
    redirect_to_next_object(:prev, Name, params[:id].to_s)
  end

  alias_method :prev_name, :show_prev

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status
    pass_query_params
    id = params[:id].to_s
    desc = Name::Description.find(id)
    desc.update_review_status(params[:value]) if reviewer?
    # redirect_with_query(
    #   action: :show,
    #   id: desc.name_id
    # )
    redirect_to name_path(@desc.name_id, q: get_query_param)
  end

end
