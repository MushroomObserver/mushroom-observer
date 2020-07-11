class RssLogsController < ApplicationController
  # The main page for logged-in users.

  before_action :login_required, except: [
    :index,
    :index_rss_log,
    :list_rss_logs, # aliased
    :next_rss_log, # aliased
    :prev_rss_log, # aliased
    :rss,
    :show,
    :show_next,
    :show_prev,
    :show_rss_log, # aliased
    :show_selected_rss_logs
  ]

  # Set query to all RssLog's and pass to show_selected_rss_logs
  # This is currently the default main page
  def index
    query = create_query(
      :RssLog,
      :all,
      type: @user ? @user.default_rss_type : "all"
    )
    show_selected_rss_logs(query)
  end

  alias_method :list_rss_logs, :index

  # TODO: Try simpler param handling here?
  # Incoming requests will have query parameters and Rails can prolly parse
  # without this controller needing to parse them explicitly
  # Maybe this is done so the parameters persist through the session?

  # Set a query from POST or given params, and pass to show_selected_rss_logs
  def index_rss_log
    if request.method == "POST"
      types = RssLog.all_types.select { |type| params["show_#{type}"] == "1" }
      types = "all" if types.length == RssLog.all_types.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
      query = find_or_create_query(:RssLog, type: types)
    elsif params[:type].present?
      types = params[:type].split & (["all"] + RssLog.all_types)
      query = find_or_create_query(
        :RssLog,
        type: types.join(" ")
      )
    # If no query params, force the "All types" params
    # TODO: Isn't this already parsed by the query?
    else
      query = find_query(:RssLog)
      query ||= create_query(
        :RssLog,
        :all,
        type: @user ? @user.default_rss_type : "all"
      )
    end
    show_selected_rss_logs(
      query,
      id: params[:id].to_s,
      always_index: true
    )
  end

  # Show selected search results as a matrix with "list_rss_logs" template.
  def show_selected_rss_logs(query, args = {})
    store_query_in_session(query)
    query_params_set(query)

    args = {
      action: :index,
      matrix: true,
      include: {
        location: :user,
        name: :user,
        observation: [
          :location,
          :name,
          { thumb_image: :image_votes },
          :user
        ],
        project: :user,
        species_list: [
          :location,
          :user
        ]
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
        # @links << [ :rss_make_default.t,
        #             add_query_param(
        #               action: :index_rss_log,
        #               make_default: 1
        #             ) ]
        @links << [:rss_make_default.t,
                   rss_logs_path(make_default: 1, q: get_query_param)]
      end
    end

    show_index_of_objects(query, args)
  end

  # Show a single RssLog.
  def show
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(
      RssLog,
      params["id"]
    )
  end

  alias_method :show_rss_log, :show

  # Go to next RssLog: redirects to show_<object>.
  def show_next
    redirect_to_next_object(
      :next,
      RssLog,
      params[:id].to_s
    )
  end

  alias_method :next_rss_log, :show_next

  # Go to previous RssLog: redirects to show_<object>.
  def show_prev
    redirect_to_next_object(
      :prev,
      RssLog,
      params[:id].to_s
    )
  end

  alias_method :prev_rss_log, :show_prev

  # This is the site's rss feed.
  def rss
    @logs = RssLog.includes(:name, :species_list, observation: :name).
            where("datediff(now(), updated_at) <= 31").
            order(updated_at: :desc).
            limit(100)

    render_xml(layout: false)
  end

  # TODO: NIMMO This goes in ApplicationController
  # Update banner across all translations.
  def change_banner # :root: :norobots:
    if !in_admin_mode?
      flash_error(:permission_denied.t)
      # redirect_to controller: :rss_logs, action: :index
      redirect_to rss_logs_path
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      time = Time.zone.now
      Language.all.each do |lang|
        if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
          str.update!(
            text: @val,
            updated_at: (str.language.official ? time : time - 1.minute)
          )
        else
          str = lang.translation_strings.create!(
            tag: "app_banner_box",
            text: @val,
            updated_at: time - 1.minute
          )
        end
        str.update_localization
        str.language.update_localization_file
        str.language.update_export_file
      end
      # redirect_to controller: :rss_logs, action: :index
      redirect_to rss_logs_path
    else
      @val = :app_banner_box.l.to_s
    end
  end

end
