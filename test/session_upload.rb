# frozen_string_literal: true

class FileUpload
  attr_accessor :filename, :content_type

  def initialize(filename, content_type)
    self.filename = filename
    self.content_type = content_type
  end
end

class JpegUpload < FileUpload
  def initialize(filename)
    super(filename, "image/jpeg")
  end
end
