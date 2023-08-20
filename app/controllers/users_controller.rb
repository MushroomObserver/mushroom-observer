# frozen_string_literal: true

# display information about, and edit, users
class UsersController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  before_action :login_required

  # User index
  def index
    return user_search if params[:pattern].present?

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

  # show.rhtml
  def show
    store_location
    id = params[:id].to_s
    @show_user = find_or_goto_index(User, id)

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, User, id) and return
    when "prev"
      redirect_to_next_object(:prev, User, id) and return
    end
    # NOTE: Using resource routes, Rails won't route anything to this show
    # action unless there's an id param, so this may be superfluous.
    return unless @show_user

    @user_data = SiteData.new.get_user_data(id)
    @life_list = Checklist::ForUser.new(@show_user)
    instance_vars_for_thumbnails_in_summary!
  end

  alias show_user show

  #############################################################################

  private

  # Display list of User's whose name, notes, etc. match a string pattern.
  def user_search
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) && (user = User.safe_find(pattern))
      redirect_to(user_path(user.id))
    else
      query = create_query(:User, :pattern_search, pattern: pattern)
      show_selected_users(query, no_hits_title: :title_for_user_search.t)
    end
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

  # set @observations whose thumbnails will display in user summary
  def instance_vars_for_thumbnails_in_summary!
    @query = Query.lookup(:Observation, :by_user, user: @show_user,
                                                  by: :owners_thumbnail_quality)
    image_includes = { thumb_image: [:image_votes, :license, :user] }
    @observations = @query.results(limit: 6, include: image_includes)
    return unless @observations.length < 6

    @query = Query.lookup(:Observation, :by_user, user: @show_user,
                                                  by: :thumbnail_quality)
    @observations = @query.results(limit: 6, include: image_includes)
  end
end
