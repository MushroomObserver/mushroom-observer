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

  private

  def default_sort_order
    ::Query::RssLogs.default_order # :updated_at
  end

  def unfiltered_index_opts
    super.merge(query_args: { type: index_type_default })
  end

  def index_type_default
    @user ? @user.default_rss_type : "all"
  end

  # ApplicationController uses this to dispatch #index to a private method
  def index_active_params
    [:type, :by, :q, :id].freeze
  end

  # Show selected list, based on current Query.
  def sorted_index_opts
    super.deep_merge(
      query_args: { type: index_type_from_params || index_type_default }
    )
  end

  # Redirect old-style top-level type param to proper q param URL.
  # This handles bookmarked URLs like /activity_logs?type=observation
  def type
    validated_type = validate_type_param(params[:type])
    redirect_to(activity_logs_path(q: { model: "RssLog", type: validated_type }))
  end

  # Validate type param (array or string) and return sanitized string
  def validate_type_param(param)
    if param.is_a?(Array)
      validate_type_array(param)
    elsif param.is_a?(String)
      validate_type_string(param)
    else
      "all"
    end
  end

  # Get the types whose value == "1"
  # Handles:
  # - String types from pagination/bookmarks: "observation name"
  # - Array types from form checkboxes: ["observation", "name"]
  # - Old-style top-level type param for backwards compatibility
  def index_type_from_params
    types = ""
    param = if (query = query_from_q_param)
              # Query validated type as string; if nil, check raw q param
              query.params[:type] || params.dig(:q, :type)
            else
              params[:type]
            end

    if param.is_a?(Array)
      types = validate_type_array(param)
    elsif param.is_a?(String)
      types = validate_type_string(param)
    end
    types
  end

  # Validate array of types (from form checkboxes or bookmarked URLs)
  def validate_type_array(param)
    valid_tags = RssLog::ALL_TYPE_TAGS.map(&:to_s)
    validated = param.map(&:to_s).select { |t| valid_tags.include?(t) }
    return "none" if validated.empty?
    return "all" if validated.length == valid_tags.length

    validated.join(" ")
  end

  # Validate type string to ensure only valid type tags are used
  def validate_type_string(param)
    return param if param.in?(%w[all none])

    valid_tags = RssLog::ALL_TYPE_TAGS.map(&:to_s)
    validated = param.split.select { |t| valid_tags.include?(t) }
    return "none" if validated.empty?
    return "all" if validated.length == valid_tags.length

    validated.join(" ")
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, _display_opts)
    # store_query_in_session(query)
    update_stored_query(query) # also stores query in session
    @types = query.params[:type].to_s.split.sort

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
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, RssLog, params[:id].to_s)
    when "prev"
      redirect_to_next_object(:prev, RssLog, params[:id].to_s)
    else
      @rss_log = find_or_goto_index(RssLog, params["id"])
    end
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
      observation: [
        :location, :name, :user, observation_matrix_box_image_includes
      ],
      project: [:location, :user],
      species_list: [:location, :user]
    }
  end
end
