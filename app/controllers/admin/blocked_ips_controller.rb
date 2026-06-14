# frozen_string_literal: true

module Admin
  class BlockedIpsController < AdminController
    IPS_PER_PAGE = 50

    # This page allows editing of blocked ips via params
    # params[:add_okay] and params[:add_bad]
    # Using params[:report] will show info about a chosen IP
    def edit
      @ip = params[:report] if validate_ip!(params[:report])
      @stats = IpStats.read_stats(do_activity: true)
      @okay = load_paginated_ip_list(:okay)
      @blocked = load_paginated_ip_list(:blocked)
      render_edit_view
    end

    # Render the page after an update
    def update
      strip_params!
      process_blocked_ips_commands
      @stats = IpStats.read_stats(do_activity: true)
      @okay = load_paginated_ip_list(:okay)
      @blocked = load_paginated_ip_list(:blocked)
      render_edit_view
    end

    private

    def render_edit_view
      render(Views::Controllers::Admin::BlockedIps::Edit.new(
               ip: @ip, stats: @stats,
               okay: @okay, blocked: @blocked,
               users_by_id: preloaded_users_for(@stats),
               api_keys_by_str: preloaded_api_keys_for(@stats)
             ))
    end

    # Preloads of the Users / APIKeys the right-column subviews will
    # display. Computed once in the controller so the views don't run
    # per-row `User.safe_find` / `APIKey.find_by(...)` queries (the
    # `find_by(` shape is also blocked by `no_queries_in_phlex_views_test`).
    def preloaded_users_for(stats)
      ids = stats.values.filter_map { |s| s[:user] }.uniq
      User.where(id: ids).index_by(&:id)
    end

    def preloaded_api_keys_for(stats)
      strs = stats.values.filter_map { |s| s[:api_key] }.uniq
      APIKey.where(key: strs).includes(:user).index_by(&:key)
    end

    # Builds an `Admin::BlockedIps::IpListState` for either the
    # okay or blocked list — both use the same shape (sort, filter
    # by starts_with, paginate). The only difference is the source
    # data and which params they read.
    def load_paginated_ip_list(type)
      all_ips = sort_by_ip(read_all_ips(type))
      starts_with = filter_param_for(type)
      if starts_with
        all_ips = all_ips.select do |ip|
          ip.start_with?(starts_with)
        end
      end

      total = all_ips.size
      page = (params[page_param_for(type)].presence || 1).to_i
      total_pages = [(total.to_f / IPS_PER_PAGE).ceil, 1].max
      offset = (page - 1) * IPS_PER_PAGE

      ::Admin::BlockedIps::IpListState[
        ips: all_ips[offset, IPS_PER_PAGE] || [],
        page: page, total_pages: total_pages,
        total_count: total, starts_with: starts_with
      ]
    end

    def read_all_ips(type)
      type == :okay ? IpStats.read_okay_ips : IpStats.read_blocked_ips
    end

    def filter_param_for(type)
      key = type == :okay ? :okay_filter : :text_filter
      params.dig(key, :starts_with).presence
    end

    def page_param_for(type)
      type == :okay ? :okay_page : :page
    end

    def strip_params!
      [:add_bad, :remove_bad, :add_okay, :remove_okay].each do |param|
        params[param] = params[param].strip if params[param]
      end
      # Also handle nested params from Superform (blocked_ips[add_bad])
      normalize_nested_params(:blocked_ips, :add_bad)
      normalize_nested_params(:okay_ips, :add_okay)
    end

    # Copy nested param to top level if present (for Superform compatibility)
    def normalize_nested_params(namespace, param)
      value = params.dig(namespace, param)
      params[param] = value.strip if value.present?
    end

    def sort_by_ip(ips)
      # convert IP addr segments to integers, sort based on those integers
      ips.sort_by { |ip| ip.split(".").map(&:to_i) }
    end

    # I think this is as good as it gets: just a simple switch statement of
    # one-line commands.  Breaking this up doesn't make sense to me.
    # -JPH 2020-10-09
    def process_blocked_ips_commands
      if validate_ip!(params[:add_okay])
        IpStats.add_okay_ips([params[:add_okay]])
      elsif validate_ip!(params[:add_bad])
        IpStats.add_blocked_ips([params[:add_bad]])
      elsif validate_ip!(params[:remove_okay])
        IpStats.remove_okay_ips([params[:remove_okay]])
      elsif validate_ip!(params[:remove_bad])
        IpStats.remove_blocked_ips([params[:remove_bad]])
      elsif params[:clear_okay].present?
        IpStats.clear_okay_ips
      elsif params[:clear_bad].present?
        IpStats.clear_blocked_ips
      end
    end

    def validate_ip!(ip)
      return false if ip.blank?

      match = ip.to_s.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
      return true if match &&
                     valid_ip_num?(match[1]) &&
                     valid_ip_num?(match[2]) &&
                     valid_ip_num?(match[3]) &&
                     valid_ip_num?(match[4])

      flash_error("Invalid IP address: \"#{ip}\"")
    end

    def valid_ip_num?(num)
      (0..255).cover?(num.to_i)
    end
  end
end
