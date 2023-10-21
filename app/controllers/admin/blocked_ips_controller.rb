# frozen_string_literal: true

module Admin
  class BlockedIpsController < AdminController
    # This page allows editing of blocked ips via params
    # params[:add_okay] and params[:add_bad]
    # GETting this page with params[:report] will show info about a chosen IP
    def edit
      @ip = params[:report] if validate_ip!(params[:report])
      @blocked_ips = sort_by_ip(IpStats.read_blocked_ips)
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(do_activity: true)
    end

    # Render the page after an update
    def update
      process_blocked_ips_commands
      @blocked_ips = sort_by_ip(IpStats.read_blocked_ips)
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(do_activity: true)
      render(action: :edit)
    end

    private

    def sort_by_ip(ips)
      ips.sort_by do |ip|
        ip.to_s.split(".").map { |n| n.to_i + 1000 }.map(&:to_s).join(" ")
      end
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
                     valid_ip_num(match[1]) &&
                     valid_ip_num(match[2]) &&
                     valid_ip_num(match[3]) &&
                     valid_ip_num(match[4])

      flash_error("Invalid IP address: \"#{ip}\"")
    end

    def valid_ip_num(num)
      num.to_i >= 0 && num.to_i < 256
    end
  end
end
