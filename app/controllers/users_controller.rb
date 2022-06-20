# frozen_string_literal: true

# display infornation about, and edit, users
class UsersController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  before_action :login_required
  before_action :disable_link_prefetching

  # User index, restricted to admins.
  def index
    return patterned_index if params[:pattern].present?

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

  # User index, restricted to admins.
  def by_name
    if in_admin_mode?
      query = create_query(:User, :all, by: :name)
      show_selected_users(query)
    else
      flash_error(:permission_denied.t)
      redirect_to("/")
    end
  end

  # by_contribution.rhtml
  def by_contribution
    SiteData.new
    @users = User.by_contribution
    render(template: "users/by_contribution")
  end

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
    # FIXME: Rails won't route anything to the show action unless there's an id!
    return unless @show_user

    @user_data = SiteData.new.get_user_data(id)
    @life_list = Checklist::ForUser.new(@show_user)
    instance_vars_for_thumbnails_in_summary!
  end

  alias show_user show

  def edit
    return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

    redirect_to(user_path(@user2.id)) unless in_admin_mode?

    # Reformat bonuses as string for editing, one entry per line.
    @val = if @user2.bonuses
             vals = @user2.bonuses.map do |points, reason|
               format("%<points>-6d %<reason>s",
                      points: points, reason: reason.gsub(/\s+/, " "))
             end
             vals.join("\n")
           else
             ""
           end
  end

  def update
    return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

    redirect_to(user_path(@user2.id)) unless in_admin_mode?

    # Parse new set of values.
    @val = params[:val]
    bonuses = calculate_bonuses
    return if bonuses.nil?

    update_user_contribution(bonuses)
    redirect_to(user_path(@user2.id))
  end

  private

  # Display list of User's whose name, notes, etc. match a string pattern.
  def patterned_index
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (user = User.safe_find(pattern))
      redirect_to(user_path(user.id))
    else
      query = create_query(:User, :pattern_search, pattern: pattern)
      show_selected_users(query)
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

    # Add some alternate sorting criteria.
    args[:sorting_links] = if in_admin_mode?
                             [
                               ["id",          :sort_by_id.t],
                               ["login",       :sort_by_login.t],
                               ["name",        :sort_by_name.t],
                               ["created_at",  :sort_by_created_at.t],
                               ["updated_at",  :sort_by_updated_at.t],
                               ["last_login",  :sort_by_last_login.t]
                             ]
                           else
                             [
                               ["login",         :sort_by_login.t],
                               ["name",          :sort_by_name.t],
                               ["created_at",    :sort_by_created_at.t],
                               ["location",      :sort_by_location.t],
                               ["contribution",  :sort_by_contribution.t]
                             ]
                           end

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

  def calculate_bonuses
    line_num = 0
    bonuses = []
    @val.split("\n").each do |line|
      line_num += 1
      if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
        bonuses.push([match[1].to_i, match[2].to_s])
      else
        flash_error("Syntax error on line #{line_num}.")
        return nil
      end
    end
    bonuses
  end

  def update_user_contribution(bonuses)
    contrib = @user2.contribution.to_i
    # Subtract old bonuses.
    @user2.bonuses&.each_key do |points|
      contrib -= points
    end
    # Add new bonuses
    bonuses.each do |(points, _reason)|
      contrib += points
    end
    # Update database.
    @user2.bonuses      = bonuses
    @user2.contribution = contrib
    @user2.save
  end
end
