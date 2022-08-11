# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::Show
  # Display observation and related namings, comments, votes, images, etc.
  # This should be a redirection, not rendered, due to large number of
  # @variables that need to be set up for the view.  Lots of views are used:
  #   observations/show
  #   _show_observation
  #   _show_images
  #   _show_namings
  #   _show_comments
  #   _show_footer
  # Linked from countless views as a fall-back.
  # Inputs: params[:id]
  # Outputs:
  #   @observation
  #   @canonical_url
  #   @mappable
  #   @new_sites
  #   @votes
  def show
    pass_query_params
    store_location
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Observation, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, Observation, params[:id]) and return
    end

    check_if_user_wants_to_make_their_votes_public
    check_if_user_wants_to_change_thumbnail_size
    return unless load_observation_for_show_observation_page

    update_view_stats(@observation)
    @canonical_url = canonical_url(@observation)
    @mappable      = check_if_query_is_mappable
    @new_sites     = external_sites_user_can_add_links_to(@observation)
    @votes         = @user ? gather_users_votes(@observation, @user) : []
  end

  def load_observation_for_show_observation_page
    includes = @user ? show_obs_heavy_includes : show_obs_light_includes
    @observation = Observation.includes(includes).find_by(id: params[:id]) ||
                   flash_error_and_goto_index(Observation, params[:id])
  end

  def show_obs_light_includes
    [
      { comments: :user },
      { images: [:license, :user] },
      :location,
      :name,
      { namings: :name },
      :user
    ]
  end

  def show_obs_heavy_includes
    [
      :collection_numbers,
      { comments: :user },
      { external_links: { external_site: :project } },
      { herbarium_records: [{ herbarium: :curators }, :user] },
      { images: [:image_votes, :license, :projects, :user] },
      :location,
      :name,
      { namings: [:name, :user, { votes: [:observation, :user] }] },
      :projects,
      :sequences,
      { species_lists: :projects },
      :user
    ]
  end

  # Make it really easy for users to elect to go public with their votes.
  def check_if_user_wants_to_make_their_votes_public
    if params[:go_public] == "1"
      @user.votes_anonymous = :no
      @user.save
      flash_notice(:show_votes_gone_public.t)
    elsif params[:go_private] == "1"
      @user.votes_anonymous = :yes
      @user.save
      flash_notice(:show_votes_gone_private.t)
    end
  end

  # Make it easy for users to change thumbnail size.
  def check_if_user_wants_to_change_thumbnail_size
    return if params[:set_thumbnail_size].blank?

    default_thumbnail_size_set(params[:set_thumbnail_size])
  end

  # Tell search engines what the "correct" URL is for this page.
  # Used in layouts/application
  def canonical_url(obs)
    observation_url(obs.id)
  end

  # Decide if the current query can be used to create a map.
  def check_if_query_is_mappable
    query = find_query(:Observation)
    query&.coercable?(:Location)
  end

  # Get a list of external_sites which the user has permission to add
  # external_links to (and which no external_link to exists yet).
  def external_sites_user_can_add_links_to(obs)
    return [] unless @user

    obs_site_ids = obs.external_links.map(&:external_site_id)
    if @user == obs.user || in_admin_mode?
      ExternalSite.where.not(id: obs_site_ids)
    else
      @user.external_sites.where.not(id: obs_site_ids)
    end
  end
end
