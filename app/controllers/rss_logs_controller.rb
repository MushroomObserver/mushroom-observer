# frozen_string_literal: true

class RssLogsController < ApplicationController
  # Uncertain these are necessary, can delete if not.
  require "find"
  require "set"

  before_action :login_required, except: [
    :index,
    :rss,
    :show
  ]
  before_action :disable_link_prefetching

  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  # Displays matrix of selected RssLog's (based on current Query, if exists).
  def index
    # POST requests with param `type` potentially show an array of types
    # of objects. The array comes from the checkboxes in tabset
    if params[:type].present?
      types = Array(params[:type])
      types = RssLog.all_types.intersection(types)
      types = "all" if types.length == RssLog.all_types.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
      query = find_or_create_query(:RssLog, type: types)
    # Previously saved query, incorporating type and other params
    elsif params[:q].present?
      query = find_query(:RssLog)
      query ||= create_query(:RssLog, :all,
                             type: @user ? @user.default_rss_type : "all")
    # Fresh version of the index, no existing query
    else
      query = create_query(:RssLog, :all,
                           type: @user ? @user.default_rss_type : "all")
    end
    show_selected_rss_logs(query, id: params[:id].to_s, always_index: true)
  end

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

  private

  # Show selected search results as a matrix with "index" template.
  def show_selected_rss_logs(query, args = {})
    store_query_in_session(query)
    query_params_set(query)

    includes = {
      article: :user,
      glossary_term: :user,
      location: :user,
      name: :user,
      observation: [:location, :name, :user,
                    @user ? { thumb_image: :image_votes } : :thumb_image],
      project: :user,
      species_list: [:location, :user]
    }

    args = {
      action: :index,
      matrix: true,
      include: includes
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
                   add_query_param(action: :index, make_default: 1)]
      end
    end

    show_index_of_objects(query, args)
  end
end
