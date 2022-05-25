# config/initializers/mail_patch.rb
# Resolves an issue in mail 2.7.1 and above, where newlines are inserted
# in mail body every x characters. This allows tests to pass
module Mail
  module Utilities
    def self.safe_for_line_ending_conversion?(string)
      string.ascii_only?
    end
  end
end
