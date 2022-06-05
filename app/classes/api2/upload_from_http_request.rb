# frozen_string_literal: true

# API2
class API2
  # Class encapsulating an upload sent as an attachement to the HTTP request
  class UploadFromHTTPRequest < Upload
    def initialize(upload)
      super()
      self.content        = upload.data
      self.content_length = upload.length
      self.content_type   = upload.content_type
      self.content_md5    = upload.checksum
    end
  end
end
