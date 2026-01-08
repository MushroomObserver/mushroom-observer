# frozen_string_literal: true

module Admin
  class BlockedIpsController < AdminController
    BLOCKED_IPS_PER_PAGE = 100

    # This page allows editing of blocked ips via params
    # params[:add_okay] and params[:add_bad]
    # Using params[:report] will show info about a chosen IP
    def edit
      @ip = params[:report] if validate_ip!(params[:report])
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(do_activity: true)
      load_paginated_blocked_ips
    end

    # Render the page after an update
    def update
      strip_params!
      process_blocked_ips_commands
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(do_activity: true)
      load_paginated_blocked_ips
      render(action: :edit)
    end

    private

    def load_paginated_blocked_ips
      all_blocked = sort_by_ip(IpStats.read_blocked_ips)
      @blocked_ips_total = all_blocked.size
      @blocked_ips_page = (params[:blocked_page].presence || 1).to_i
      @blocked_ips_pages = (@blocked_ips_total.to_f / BLOCKED_IPS_PER_PAGE).ceil
      offset = (@blocked_ips_page - 1) * BLOCKED_IPS_PER_PAGE
      @blocked_ips = all_blocked[offset, BLOCKED_IPS_PER_PAGE] || []
    end

    def strip_params!
      [:add_bad, :remove_bad, :add_okay, :remove_okay].each do |param|
        params[param] = params[param].strip if params[param]
      end
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
