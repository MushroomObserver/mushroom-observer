module Rack
  module Test
    # Simple extension of Rack::Text::UploadedFile which works with StringIO
    # instead # of an actual file that has to be saved somewhere on the local
    # filesystem.
    #
    #   post :upload, :file => Rack::Test::UploadedString(
    #     "file contents", "text/plain", "original_filename.txt"
    #   )
    #
    class UploadedString < UploadedFile
      def initialize(string,
                     content_type = "text/plain",
                     original_filename = "stringio.txt")
        @content_type = content_type
        @original_filename = original_filename
        @tempfile = StringIO.new(string)
      end
    end
  end
end
