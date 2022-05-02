# frozen_string_literal: true

class IpStats
  class << self
    STATS_TIME = 10 # minutes

    # Call after request done, passing in these data:
    #   ip::         IP address (string)
    #   time::       Time request started.
    #   controller:: Controller (string).
    #   action::     Action (string).
    #   api_key::    API key (string).
    def log_stats(stats)
      file = MO.ip_stats_file
      now = Time.now.utc
      File.open(file, "a") do |fh|
        fh.puts([
          stats[:time].utc,
          stats[:ip],
          User.current_id,
          now - stats[:time].utc,
          stats[:controller],
          stats[:action],
          stats[:api_key]
        ].join(","))
      end
    end

    # Returns data for each IP address:
    #   user::     User ID if logged in, first of any to use this IP (integer).
    #   api_key::  API key if given, first of any to use this IP (string).
    #   load::     Percentage of time of one server instance used (float).
    #   rate::     Rate of requests per second (float).
    #   activity:: Array of recent activity, each entry an Array of four data:
    #     time::       Time request started.
    #     load::       Time used to serve request in seconds (float).
    #     controller:: Controller (string).
    #     action::     Action (string).
    def read_stats(do_activity = false)
      data = {}
      now = Time.now.utc
      file = MO.ip_stats_file
      read_file(file) do |*vals|
        add_one_line_to_stats(data, vals, now, do_activity)
      end
      data
    end

    def add_one_line_to_stats(data, vals, now, do_activity)
      time, ip, _user, _load, controller, _action, _api_key = *vals
      hash = data[ip] ||= { load: 0, activity: [], rate: 0 }
      weight = calc_weight(now, Time.parse(time).utc)
      weight /= 2 if controller.to_s == "api"
      update_one_stat(hash, vals, weight, do_activity)
    end

    def update_one_stat(hash, vals, weight, do_activity)
      time, ip, user, load, controller, action, api_key = *vals
      hash[:ip] = ip
      hash[:user] ||= user.to_i if user.to_s != ""
      hash[:api_key] ||= api_key.to_s if api_key.to_s != ""
      hash[:load] += load.to_f * weight
      hash[:rate] += weight
      hash[:activity] << [time, load.to_f, controller, action] \
        if do_activity
    end

    def clean_stats
      cutoff = (Time.now.utc - STATS_TIME * 60).to_s
      rewrite_ip_stats { |time| time > cutoff }
    end

    def okay?(ip)
      populate_blocked_ips unless blocked_ips_current?
      @@okay_ips.include?(ip)
    end

    def blocked?(ip)
      populate_blocked_ips unless blocked_ips_current?
      @@blocked_ips.include?(ip) && @@okay_ips.exclude?(ip)
    end

    def blocked_ips
      populate_blocked_ips unless blocked_ips_current?
      @@blocked_ips - @@okay_ips
    end

    def add_blocked_ips(ips)
      add_ips(ips, MO.blocked_ips_file)
    end

    def add_okay_ips(ips)
      add_ips(ips, MO.okay_ips_file)
    end

    def add_ips(ips, file)
      File.open(file, "a") do |fh|
        ips.each do |ip|
          fh.puts("#{ip},#{Time.now.utc}")
        end
      end
    end

    def remove_blocked_ips(ips)
      rewrite_blocked_ips { |ip, _time| ips.exclude?(ip) }
    end

    def remove_okay_ips(ips)
      rewrite_okay_ips { |ip, _time| ips.exclude?(ip) }
    end

    def clear_blocked_ips
      File.truncate(MO.blocked_ips_file, 0)
    end

    def clear_okay_ips
      File.truncate(MO.okay_ips_file, 0) {}
    end

    def clean_blocked_ips
      cutoff = (Time.now.utc - 24 * 60 * 60).to_s
      rewrite_blocked_ips { |_ip, time| time > cutoff }
    end

    def read_blocked_ips
      parse_ip_list(MO.blocked_ips_file)
    end

    def read_okay_ips
      parse_ip_list(MO.okay_ips_file)
    end

    def reset!
      # Force reload next time used.
      @@blocked_ips_time = nil
    end

    # -------------------------------------

    private

    # Weight turns rate into average number of requests per second,
    # and load into average percentage of server time used.  It weights
    # recent activity more heavily than old activity.
    def calc_weight(now, time)
      return 0.0 if now - time > 60 * STATS_TIME

      (60 * STATS_TIME - (now - time)) /
        STATS_TIME / STATS_TIME / 60 / 60 * 2
    end

    def blocked_ips_current?
      defined?(@@blocked_ips_time) &&
        @@blocked_ips_time.to_s != "" &&
        @@blocked_ips_time >= File.mtime(MO.blocked_ips_file) &&
        @@blocked_ips_time >= File.mtime(MO.okay_ips_file)
    end

    def populate_blocked_ips
      file1 = MO.blocked_ips_file
      file2 = MO.okay_ips_file
      @@blocked_ips = parse_ip_list(file1)
      @@okay_ips = parse_ip_list(file2)
      @@blocked_ips_time = [File.mtime(file1), File.mtime(file2)].max
    end

    def parse_ip_list(file)
      FileUtils.touch(file) unless File.exist?(file)
      File.open(file).readlines.map do |line|
        line.chomp.split(",").first
      end
    end

    def rewrite_blocked_ips(&block)
      rewrite_file(MO.blocked_ips_file, &block)
    end

    def rewrite_okay_ips(&block)
      rewrite_file(MO.okay_ips_file, &block)
    end

    def rewrite_ip_stats(&block)
      rewrite_file(MO.ip_stats_file, &block)
    end

    def read_file(file)
      File.open(file, "r") do |fh|
        fh.each_line do |line|
          yield(*line.chomp.split(","))
        end
      end
    end

    def rewrite_file(file1)
      file2 = "#{file1}.#{Process.pid}"
      File.open(file1, "r") do |fh1|
        File.open(file2, "w") do |fh2|
          fh1.each_line do |line|
            fh2.write(line) if yield(*line.chomp.split(","))
          end
        end
      end
      File.delete(file1)
      File.rename(file2, file1)
    end
  end
end
