module Rack
  module Test
    class UploadedString < UploadedFile
      def initialize(string, content_type = "text/plain", original_filename = "stringio.txt")
        @content_type = content_type
        @original_filename = original_filename
        @tempfile = StringIO.new(string)
      end
    end
  end
end
