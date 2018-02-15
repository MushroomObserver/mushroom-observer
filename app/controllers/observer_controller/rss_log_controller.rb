# TODO: move this into new RssLogController
class ObserverController
  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  def index # :nologin:
    list_rss_logs
  end

  # Displays matrix of selected RssLog's (based on current Query).
  def index_rss_log # :nologin: :norobots:
    if request.method == "POST"
      types = RssLog.all_types.select { |type| params["show_#{type}"] == "1" }
      types = "all" if types.length == RssLog.all_types.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
      query = find_or_create_query(:RssLog, type: types)
    elsif !params[:type].blank?
      types = params[:type].split & (["all"] + RssLog.all_types)
      query = find_or_create_query(:RssLog, type: types.join(" "))
    else
      query = find_query(:RssLog)
      query ||= create_query(:RssLog, :all,
                             type: @user ? @user.default_rss_type : "all")
    end
    show_selected_rss_logs(query, id: params[:id].to_s, always_index: true)
  end

  # This is the main site index.  Nice how it's buried way down here, huh?
  def list_rss_logs # :nologin:
    query = create_query(:RssLog, :all,
                         type: @user ? @user.default_rss_type : "all")
    show_selected_rss_logs(query)
  end

  # Show selected search results as a matrix with "list_rss_logs" template.
  def show_selected_rss_logs(query, args = {})
    store_query_in_session(query)
    query_params_set(query)

    args = {
      action: "list_rss_logs",
      matrix: true,
      include: {
        location: :user,
        name: :user,
        observation: [:location, :name, { thumb_image: :image_votes }, :user],
        project: :user,
        species_list: [:location, :user]
      }
    }.merge(args)

    @types = query.params[:type].to_s.split.sort
    @links = []

    # Let the user make this their default and fine tune.
    if @user
      if params[:make_default] == "1"
        @user.default_rss_type = @types.join(" ")
        @user.save_without_our_callbacks
      elsif @user.default_rss_type.to_s.split.sort != @types
        @links << [:rss_make_default.t,
                   add_query_param(action: "index_rss_log", make_default: 1)]
      end
    end

    show_index_of_objects(query, args)
  end

  # Show a single RssLog.
  def show_rss_log # :nologin:
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(RssLog, params["id"])
  end

  # Go to next RssLog: redirects to show_<object>.
  def next_rss_log # :nologin: :norobots:
    redirect_to_next_object(:next, RssLog, params[:id].to_s)
  end

  # Go to previous RssLog: redirects to show_<object>.
  def prev_rss_log # :nologin: :norobots:
    redirect_to_next_object(:prev, RssLog, params[:id].to_s)
  end

  # This is the site's rss feed.
  def rss # :nologin:
    @logs = RssLog.includes(:name, :species_list, observation: :name).
            where("datediff(now(), updated_at) <= 31").
            order(updated_at: :desc).
            limit(100)

    render_xml(layout: false)
  end
end
