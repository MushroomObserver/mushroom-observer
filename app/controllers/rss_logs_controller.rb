# frozen_string_literal: true

class RssLogsController < ApplicationController
  before_action :login_required
  before_action :store_location, only: [:show]

  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  # Displays matrix of selected RssLog's (based on current Query, if exists).
  def index
    build_index_with_query
  end

  def render_index_view
    render(Views::Controllers::RssLogs::Index.new(
             query: @query, rss_logs: @objects.to_a,
             pagination_data: @pagination_data,
             types: @types || []
           ))
  end

  private

  def default_sort_order
    ::Query::RssLogs.default_order # :updated_at
  end

  def unfiltered_index_opts
    super.merge(query_args: { types: index_type_default })
  end

  def index_type_default
    @user ? @user.default_rss_type : "all"
  end

  # ApplicationController uses this to dispatch #index to a private method.
  # `:type` (legacy scalar bookmarks) and `:types` (the type-filter form,
  # or a direct `?types[]=` URL) both resolve to the same query_attr --
  # see `Query::RssLogs`.
  def index_active_params
    [:type, :types, :by, :q, :id].freeze
  end

  # Show selected list, based on current Query.
  def sorted_index_opts
    super.deep_merge(
      query_args: { types: index_type_from_params || index_type_default }
    )
  end

  # `:type`/`:types` are plain query_attr aliases now (see
  # Query::RssLogs) -- no bookmark redirect needed, top-level params
  # are a first-class URL form.
  def type
    create_query_from_url_params(:RssLog, params)
  end
  alias types type

  # The types filter active in the current Query, if any, otherwise
  # whatever the request itself supplies -- from a stored/`q`-decoded
  # query when sorting an already-filtered index, or a fresh top-level
  # `type`/`types` param otherwise. `Query::RssLogs`'s own validation
  # normalizes whatever shape comes back.
  def index_type_from_params
    if (query = query_from_q_param)
      query.params[:types] || params.dig(:q, :types) ||
        params.dig(:q, :type)
    else
      params[:types] || params[:type]
    end
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, _display_opts)
    update_stored_query(query) # also stores query in session
    tags = RssLog.normalize_type_tags(query.params[:types])
    @types = tags.empty? ? ["none"] : tags.sort

    # Let the user make this their default and fine tune.
    if @user && params[:make_default] == "1"
      @user.default_rss_type = @types.join(" ")
      @user.save_without_our_callbacks
    end

    query
  end

  def index_display_opts(opts, _query)
    { matrix: true, cache: true,
      include: rss_log_includes }.merge(opts)
  end

  public

  # Show a single RssLog.
  def show
    return if redirect_or_find_show_target?

    render(Views::Controllers::RssLogs::Show.new(rss_log: @rss_log))
  end

  def redirect_or_find_show_target?
    flow = params[:flow]
    if %w[next prev].include?(flow)
      redirect_to_next_object(flow.to_sym, RssLog, params[:id].to_s)
    else
      @rss_log = find_or_goto_index(RssLog, params["id"])
    end
    performed? || @rss_log.nil?
  end

  # This is the site's rss feed.
  def rss
    @logs = RssLog.includes(:name, :species_list, observation: :name).
            where(updated_at: ..31.days.ago).
            order(updated_at: :desc).
            limit(100)

    render_xml(layout: false)
  end

  # rss_logs now requires a logged in user
  def rss_log_includes
    {
      article: :user,
      glossary_term: :user,
      location: :user,
      name: :user,
      observation: Observation.matrix_box_includes,
      project: [:location, :user],
      species_list: [:location, :user]
    }
  end
end
