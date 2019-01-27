# see observer_controller.rb
class ObserverController
  # Display observation and related namings, comments, votes, images, etc.
  # This should be a redirection, not rendered, due to large number of
  # @variables that need to be set up for the view.  Lots of views are used:
  #   show_observation
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
  def show_observation # :nologin: :prefetch:
    pass_query_params
    store_location
    check_if_user_wants_to_make_their_votes_public
    check_if_user_wants_to_change_thumbnail_size
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    update_view_stats(@observation)
    @canonical_url = canonical_url(@observation)
    @mappable      = check_if_query_is_mappable
    @new_sites     = external_sites_user_can_add_links_to(@observation)
    @votes         = gather_users_votes(@observation, @user) if @user
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
  def canonical_url(obs)
    "#{MO.http_domain}/observer/show_observation/#{obs.id}"
  end

  # Decide if the current query can be used to create a map.
  def check_if_query_is_mappable
    query = find_query(:Observation)
    query && query.coercable?(:Location)
  end

  # Get a list of external_sites which the user has permission to add
  # external_links to (and which no external_link to exists yet).
  def external_sites_user_can_add_links_to(obs)
    return [] unless @user

    if @user == obs.user || in_admin_mode?
      ExternalSite.all - obs.external_links.map(&:external_site)
    else
      @user.external_sites - obs.external_links.map(&:external_site)
    end
  end

  def show_obs
    redirect_to(action: "show_observation", id: params[:id].to_s)
  end

  # Go to next observation: redirects to show_observation.
  def next_observation # :nologin: :norobots:
    redirect_to_next_object(:next, Observation, params[:id].to_s)
  end

  # Go to previous observation: redirects to show_observation.
  def prev_observation # :nologin: :norobots:
    redirect_to_next_object(:prev, Observation, params[:id].to_s)
  end

  # Show map of observation.
  def map_observation # :nologin: :norobots:
    pass_query_params
    obs = find_or_goto_index(Observation, params[:id].to_s)
    return unless obs

    @title = :map_observation_title.t(id: obs.id)
    @observations = [
      MinimalMapObservation.new(obs.id, obs.lat, obs.long, obs.location)
    ]
    render(action: :map_observations)
  end
end
