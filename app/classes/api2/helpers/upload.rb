# frozen_string_literal: true

# API2
class API2
  def prepare_upload
    uploads = [upload_from_url, upload_from_file, upload_from_http]
    uploads.reject!(&:nil?)
    raise(TooManyUploads.new) if uploads.length > 1

    uploads.first
  end

  def upload_from_url
    url = parse(:string, :upload_url)
    return nil unless url

    UploadFromURL.new(url)
  end

  def upload_from_file
    file = parse(:string, :upload_file)
    return nil unless file

    UploadFromFile.new(file)
  end

  def upload_from_http
    upload = parse_upload
    return nil unless upload

    UploadFromHTTPRequest.new(upload)
  end
end
