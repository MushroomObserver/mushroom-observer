# frozen_string_literal: true

# see observer_controller.rb
class ObserverController
  # User index, restricted to admins.
  def index_user
    if in_admin_mode? || find_query(:User)
      query = find_or_create_query(:User, by: params[:by])
      show_selected_users(query, id: params[:id].to_s, always_index: true)
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # People guess this page name frequently for whatever reason, and
  # since there is a view with this name, it crashes each time.
  alias list_users index_user

  # User index, restricted to admins.
  def users_by_name
    if in_admin_mode?
      query = create_query(:User, :all, by: :name)
      show_selected_users(query)
    else
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # Display list of User's whose name, notes, etc. match a string pattern.
  def user_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (user = User.safe_find(pattern))
      redirect_to(action: "show_user", id: user.id)
    else
      query = create_query(:User, :pattern_search, pattern: pattern)
      show_selected_users(query)
    end
  end

  def show_selected_users(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_users",
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

  # users_by_contribution.rhtml
  def users_by_contribution
    SiteData.new
    @users = User.order("contribution desc, name, login")
  end

  # show_user.rhtml
  def show_user
    store_location
    id = params[:id].to_s
    @show_user = find_or_goto_index(User, id)
    return unless @show_user

    @user_data = SiteData.new.get_user_data(id)
    @life_list = Checklist::ForUser.new(@show_user)
    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :owners_thumbnail_quality)
    @observations = @query.results(limit: 6)
    return unless @observations.length < 6

    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :thumbnail_quality)
    @observations = @query.results(limit: 6)
  end

  # Go to next user: redirects to show_user.
  def next_user
    redirect_to_next_object(:next, User, params[:id].to_s)
  end

  # Go to previous user: redirects to show_user.
  def prev_user
    redirect_to_next_object(:prev, User, params[:id].to_s)
  end

  # Display a checklist of species seen by a User, Project,
  # SpeciesList or the entire site.
  def checklist
    store_location
    user_id = params[:user_id] || params[:id]
    proj_id = params[:project_id]
    list_id = params[:species_list_id]
    if user_id.present?
      if (@show_user = find_or_goto_index(User, user_id))
        @data = Checklist::ForUser.new(@show_user)
      end
    elsif proj_id.present?
      if (@project = find_or_goto_index(Project, proj_id))
        @data = Checklist::ForProject.new(@project)
      end
    elsif list_id.present?
      if (@species_list = find_or_goto_index(SpeciesList, list_id))
        @data = Checklist::ForSpeciesList.new(@species_list)
      end
    else
      @data = Checklist::ForSite.new
    end
  end

  # Admin util linked from show_user page that lets admin add or change bonuses
  # for a given user.
  def change_user_bonuses
    return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

    if in_admin_mode?
      if request.method != "POST"
        # Reformat bonuses as string for editing, one entry per line.
        @val = ""
        if @user2.bonuses
          vals = @user2.bonuses.map do |points, reason|
            format("%-6d %s", points, reason.gsub(/\s+/, " "))
          end
          @val = vals.join("\n")
        end
      else
        # Parse new set of values.
        @val = params[:val]
        line_num = 0
        errors = false
        bonuses = []
        @val.split("\n").each do |line|
          line_num += 1
          if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
            bonuses.push([match[1].to_i, match[2].to_s])
          else
            flash_error("Syntax error on line #{line_num}.")
            errors = true
          end
        end
        # Success: update user's contribution.
        unless errors
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
          redirect_to(action: "show_user", id: @user2.id)
        end
      end
    else
      redirect_to(action: "show_user", id: @user2.id)
    end
  end
end
