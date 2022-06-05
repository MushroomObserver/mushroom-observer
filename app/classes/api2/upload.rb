# frozen_string_literal: true

# API2
class API2
  # Class holding info about an upload
  class Upload
    attr_accessor :data, :length, :content_type, :checksum
    attr_accessor :content, :content_length, :content_type, :content_md5

    def initialize(args)
      @data         = args[:data]
      @length       = args[:length]
      @content_type = args[:content_type]
      @checksum     = args[:checksum]
    end

    def clean_up; end
  end
end
