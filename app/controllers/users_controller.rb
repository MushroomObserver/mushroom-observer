# frozen_string_literal: true

# display information about, and edit, users
class UsersController < ApplicationController
  before_action :login_required

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  alias index_user index
  # People guess this page name frequently for whatever reason, and
  # since there is a view with this name, it crashes each time.
  alias list_users index

  private

  # NOTE: Only admins can get the full user index.
  # Others get here via search, so they shouldn't hit unfiltered_index
  def unfiltered_index_permitted?
    index_query_authorized?
  end

  # Also used by sorted_index below
  def index_query_authorized?
    return true if in_admin_mode? || find_query(:User)

    flash_error(:runtime_search_has_expired.t)
    redirect_to("/")
    false
  end

  def default_sort_order
    ::Query::Users.default_order # :name
  end

  # Used by ApplicationController to dispatch #index to a private method
  def index_active_params
    [:pattern, :by, :q, :id].freeze
  end

  def sorted_index_permitted?
    index_query_authorized?
  end

  # Display list of Users whose name, notes, etc. match a string pattern.
  def pattern
    pattern = params[:pattern].to_s
    if (user = user_exact_match(pattern))
      redirect_to(user_path(user.id))
      [nil, {}]
    else
      query = create_query(:User, pattern: pattern)
      [query, {}]
    end
  end

  # This doesn't return direct hits on the user login or name, in case fuzzy.
  def user_exact_match(pattern)
    if ((pattern.match?(/^\d+$/) && (user = User.safe_find(pattern))) ||
       # (user = User.find_by(login: pattern)) ||
       # (user = User.find_by(name: pattern)) ||
       (user = User.find_by(email: pattern))) && user.verified
      return user
    end

    false
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, _display_opts)
    store_query_in_session(query)
    query
  end

  def index_display_opts(opts, _query)
    {
      letters: true,
      include: [:user_groups, :observations, :image],
      matrix: !in_admin_mode?
    }.merge(opts)
  end

  public

  #############################################################################

  def show
    store_location
    id = params[:id].to_s
    return unless find_user!

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, User, id) and return
    when "prev"
      redirect_to_next_object(:prev, User, id) and return
    end

    @life_list = Checklist::ForUser.new(@show_user)
    define_instance_vars_for_summary!
  end

  alias show_user show

  #############################################################################

  private

  # Note that the full user index is unavailable except to admins.
  # The index above will just redirect again, to "/"
  def find_user!
    @show_user = User.show_includes.safe_find(params[:id]) ||
                 flash_error_and_goto_index(User, params[:id])
  end

  # User's best images for #show
  MAX_THUMBS = 6
  private_constant(:MAX_THUMBS)

  # set @observations whose thumbnails will display in user summary
  def define_instance_vars_for_summary!
    @user_stats = @show_user.user_stats

    # NOTE: This query is pretty well optimized.
    # First check the user's observation thumbnails for their own favorites
    image_includes = { thumb_image: [:image_votes, :projects, :license, :user] }
    @query = Query.lookup(:Observation, by_users: @show_user,
                                        order_by: :owners_thumbnail_quality)
    observations = @query.results(limit: 6, include: image_includes)

    # If not enough, check for other people's favorites
    if (MAX_THUMBS - observations.length).positive?
      @query = Query.lookup(:Observation, by_users: @show_user,
                                          order_by: :thumbnail_quality)
      other_users_favorites = @query.results(limit: MAX_THUMBS,
                                             include: image_includes)
      observations = observations.union(other_users_favorites).take(MAX_THUMBS)
    end

    @best_images = observations.map(&:thumb_image)
  end
end
