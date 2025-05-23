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
  #   @other_sites
  #   @votes
  def show
    return if check_for_spider_block(request, params)

    pass_query_params
    store_location
    if params[:flow].present?
      redirect_to_next_object(params[:flow].to_sym, Observation, params[:id])
      return
    end

    check_if_user_wants_to_make_their_votes_public
    check_if_user_wants_to_change_thumbnail_size
    return unless load_observation_for_show_observation_page

    update_view_stats(@observation)
    @canonical_url = canonical_url(@observation)
    @mappable      = check_if_query_is_mappable
    @other_sites   = ExternalSite.sites_user_can_add_links_to(
      @user, @observation, admin: in_admin_mode?
    )
    @consensus     = Observation::NamingConsensus.new(@observation)
    @owner_name    = @consensus.owner_preference
    register_namings_for_textile_in_notes
    @comments      = @observation.comments&.sort_by(&:created_at)&.reverse
    @images        = @observation.images_sorted
  end

  def load_observation_for_show_observation_page
    includes = @user ? "show_includes" : "not_logged_in_show_includes" # scopes
    @observation = Observation.send(includes).safe_find(params[:id]) ||
                   flash_error_and_goto_index(Observation, params[:id])
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
  # Used in application/app/head
  def canonical_url(obs)
    observation_url(obs.id)
  end

  # Decide if the current query can be used to create a map.
  def check_if_query_is_mappable
    query = find_query(:Observation)
    query&.params&.dig(:location_query)
  end

  # Incurs a costly namings lookup if called in the partial outside show_obs
  # e.g., in the lightbox caption
  def register_namings_for_textile_in_notes
    return unless @observation.notes?

    Textile.register_name(*@observation.namings.map(&:name))
  end
end
