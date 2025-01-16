# frozen_string_literal: true

class RssLogsController < ApplicationController
  # Uncertain these are necessary, can delete if not.
  require "find"

  before_action :login_required, except: [
    # :index,
    :rss,
    :show
  ]

  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  # Displays matrix of selected RssLog's (based on current Query, if exists).
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    :updated_at
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
    super.merge(query_args: { type: index_type_default })
  end

  # Requests with param `type` potentially show an array of types
  # of objects. The array comes from the checkboxes in tabset
  def type
    query = find_or_create_query(:RssLog, type: index_type_from_params)
    [query, index_display_at_id_opts]
  end

  # Get the types whose value == "1"
  def index_type_from_params
    types = ""
    if params[:type].is_a?(ActionController::Parameters)
      types = params[:type].select { |_key, value| value == "1" }.keys
      types = RssLog::ALL_TYPES
.intersection(types)
      types = "all" if types.length == RssLog::ALL_TYPES
.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
    elsif params[:type].is_a?(String)
      types = params[:type]
    end
    types
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, _display_opts)
    store_query_in_session(query)
    query_params_set(query)

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
    end
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(RssLog, params["id"])
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
