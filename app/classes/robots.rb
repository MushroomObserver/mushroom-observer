# frozen_string_literal: true

# Permissions for user_agents
class Robots
  class << self
    # Is the robot authorized to be on the site?
    def authorized?(user_agent)
      # Googlebot not followed by a hyphen excludes Googlebot-Image, etc.
      /Googlebot(?!-)|bingbot/.match?(user_agent)
    end

    def action_allowed?(args)
      populate_allowed_robot_actions unless defined?(@allowed_robot_actions)
      return true if args[:controller].start_with?("api")

      @allowed_robot_actions["#{args[:controller]}/#{args[:action]}"]
    end

    def populate_allowed_robot_actions
      file = MO.robots_dot_text_file
      @allowed_robot_actions = parse_robots_dot_text(file)
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
  end
end
