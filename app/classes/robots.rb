class Robots
  class << self
    def allowed?(args)
      populate_allowed_robot_actions unless defined?(@@allowed_robot_actions)
      return true  if args[:controller] == "api"
      return false if args[:ua].downcase.include?("yandex")

      @@allowed_robot_actions["#{args[:controller]}/#{args[:action]}"]
    end

    def blocked?(ip)
      populate_blocked_ips unless blocked_ips_current?
      @@blocked_ips.include?(ip)
    end

    def populate_allowed_robot_actions
      file = MO.robots_dot_text_file
      @@allowed_robot_actions = parse_robots_dot_text(file)
    end

    def parse_robots_dot_text(file)
      results = {}
      if File.exist?(file)
        pat = Regexp.new('Allow: /(\w+)/(\w+)')
        File.open(file).readlines.each do |line|
          match = line.match(pat)
          next unless match

          controller = match[1]
          action     = match[2]
          results["#{controller}/#{action}"] = true
        end
      end
      results
    end

    def blocked_ips_current?
      defined?(@@blocked_ips_time) &&
        @@blocked_ips_time >= File.mtime(MO.blocked_ips_file)
    end

    def populate_blocked_ips
      file = MO.blocked_ips_file
      @@blocked_ips_time = File.mtime(file)
      @@blocked_ips = parse_blocked_ips(file)
    end

    def parse_blocked_ips(file)
      return [] unless File.exist?(file)

      File.open(file).readlines.map(&:chomp)
    end
  end
end
