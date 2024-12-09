# frozen_string_literal: true

# display information about, and edit, users
class UsersController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"

  before_action :login_required

  # Users index
  # TODO: Use dispatcher to provide q, id, and by params to index_query_results
  # NOTE: Only admins can get the full user index.
  # if there's a `list_all` it should check admin mode.
  # Other users get here via search.
  def index
    return user_search if params[:pattern].present?

    # This is a list_all action basically
    if in_admin_mode? || find_query(:User)
      query = find_or_create_query(:User, by: params[:by])
      show_selected_users(query, id: params[:id].to_s, always_index: true)
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_to("/")
    end
  end

  alias index_user index
  # People guess this page name frequently for whatever reason, and
  # since there is a view with this name, it crashes each time.
  alias list_users index

  private

  # TODO: rename `pattern`, check callers
  # Display list of Users whose name, notes, etc. match a string pattern.
  def user_search
    pattern = params[:pattern].to_s
    if (user = user_exact_match(pattern))
      redirect_to(user_path(user.id))
    else
      query = create_query(:User, :all, pattern: pattern)
      show_selected_users(query)
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

  def show_selected_users(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "index",
      include: :user_groups,
      matrix: !in_admin_mode?
    }.merge(args)

    # Paginate by "correct" letter.
    args[:letters] = if (query.params[:by] == "login") ||
                        (query.params[:by] == "reverse_login")
                       "users.login"
                     else
                       "users.name"
                     end

    show_index_of_objects(query, args)
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

  # set @observations whose thumbnails will display in user summary
  def define_instance_vars_for_summary!
    @user_stats = @show_user.user_stats

    # NOTE: This query is pretty well optimized.
    # First check the user's observation thumbnails for their own favorites
    image_includes = { thumb_image: [:image_votes, :projects, :license, :user] }
    @query = Query.lookup(:Observation, :by_user, user: @show_user,
                                                  by: :owners_thumbnail_quality)
    observations = @query.results(limit: 6, include: image_includes)

    # If not enough, check for other people's favorites
    if (MAX_THUMBS - observations.length).positive?
      @query = Query.lookup(:Observation, :by_user, user: @show_user,
                                                    by: :thumbnail_quality)
      other_users_favorites = @query.results(limit: MAX_THUMBS,
                                             include: image_includes)
      observations = observations.union(other_users_favorites).take(MAX_THUMBS)
    end

    @best_images = observations.map(&:thumb_image)
  end
end
