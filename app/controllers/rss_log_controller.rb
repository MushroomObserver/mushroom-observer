class RssLogController < ApplicationController
  # The main page.

  # TODO: Try simpler param handling here?
  # Incoming requests will have query parameters and Rails can prolly parse
  # without this controller needing to parse them explicitly
  # Maybe this is done so the parameters persist through the session?

  before_action :login_required, except: [
    :index,
    :index_rss_log,
    :list_rss_logs,
    :next_rss_log,
    :prev_rss_log,
    :rss,
    :show_rss_log,
    :show_selected_rss_logs
  ]

  def index
    # This redefines the query, then calls application_controller.rb action:
    # show_index_of_objects - which instantiates more variables for view
    # @timer_start @timer_end @title @num_results @sorts @pages
    list_rss_logs
  end

  # Set a query from POST or given params, and pass to show_selected_rss_logs
  def index_rss_log # :norobots:
    # If user selected checkboxes in a form submit
    # TODO: Rails can already parse POST params.
    # fix form eliminate this logic??!
    if request.method == "POST"
      types = RssLog.all_types.select { |type| params["show_#{type}"] == "1" }
      types = "all" if types.length == RssLog.all_types.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
      query = find_or_create_query(:RssLog, type: types)
    # If the parameters are otherwise present in the query string
    # TODO: Isn't this already parsed by the query?
    elsif params[:type].present?
      types = params[:type].split & (["all"] + RssLog.all_types)
      query = find_or_create_query(:RssLog, type: types.join(" "))
    # If no query params, force the "All types" params
    # TODO: Isn't this already parsed by the query?
    else
      query = find_query(:RssLog)
      query ||= create_query(:RssLog, :all,
                             type: @user ? @user.default_rss_type : "all")
    end
    show_selected_rss_logs(query, id: params[:id].to_s, always_index: true)
  end

  # Set query to all RssLog's and pass to show_selected_rss_logs
  # This is currently the default main page
  def list_rss_logs
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
  def show_rss_log
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(RssLog, params["id"])
  end

  # Go to next RssLog: redirects to show_<object>.
  def next_rss_log # :norobots:
    redirect_to_next_object(:next, RssLog, params[:id].to_s)
  end

  # Go to previous RssLog: redirects to show_<object>.
  def prev_rss_log # :norobots:
    redirect_to_next_object(:prev, RssLog, params[:id].to_s)
  end

  # This is the site's rss feed.
  def rss
    @logs = RssLog.includes(:name, :species_list, observation: :name).
            where("datediff(now(), updated_at) <= 31").
            order(updated_at: :desc).
            limit(100)

    render_xml(layout: false)
  end
end
