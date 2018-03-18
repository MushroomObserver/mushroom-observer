class Robots
  class << self
    def allowed?(args)
      populate_allowed_robot_actions unless defined?(@@allowed_robot_actions)
      return true  if args[:controller] == "api"
      return false if args[:ua].downcase.include?("yandex")
      @@allowed_robot_actions["#{args[:controller]}/#{args[:action]}"]
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
          if match
            controller = match[1]
            action     = match[2]
            results["#{controller}/#{action}"] = true
          end
        end
      end
      results
    end
  end
end
