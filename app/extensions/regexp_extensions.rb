# frozen_string_literal: true

class Regexp
  # Spaces are not Regexp meta-characters, so
  # stop Ruby from escaping them
  # Cf. https://stackoverflow.com/questions/73933394/regexp-escape-adds-weird-escapes-to-a-plain-space
  def self.escape_except_spaces(str)
    escape(str).gsub("\\ ", " ")
  end
end
