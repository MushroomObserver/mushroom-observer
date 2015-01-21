# encoding: utf-8

class Robots
  class << self
    def allowed?(controller, action)
      populate_allowed_robot_actions if !defined?(@@allowed_robot_actions)
      return @@allowed_robot_actions["#{controller}/#{action}"]
    end

    def populate_allowed_robot_actions
      file = "#{::Rails.root}/public/robots.txt"
      @@allowed_robot_actions = parse_robots_dot_text(file)
    end

    def parse_robots_dot_text(file)
      results = {}
      pat = Regexp.new('Allow: /(\w+)/(\w+)')
      File.open(file).readlines.each do |line|
        match = line.match(pat)
        if match
          controller = match[1]
          action     = match[2]
          results["#{controller}/#{action}"] = true
        end
      end
      return results
    end
  end
end
