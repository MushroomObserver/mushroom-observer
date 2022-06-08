# frozen_string_literal: true

# Resolves an issue in mail 2.7.1 and above, where newlines are inserted
# in mail body every x characters. This allows tests to pass
module Mail
  module Utilities
    def self.safe_for_line_ending_conversion?(string)
      string.ascii_only?
    end
  end
  # module Encodings
  #   class QuotedPrintable < SevenBit
  #     def self.encode(str)
  #       ::Mail::Utilities.to_crlf([::Mail::Utilities.to_lf(str)].pack("M"))
  #     end
  #   end
  # end
end
