# API
class API
  def prepare_upload
    uploads = [upload_from_url, upload_from_file, upload_from_http]
    uploads.reject!(&:nil?)
    raise TooManyUploads.new if uploads.length > 1

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

  # Class encapsulating an upload from a remote server
  class UploadFromURL < Upload
    def initialize(url)
      fetch(url)
    rescue StandardError => e
      raise CouldntDownloadURL.new(url, e)
    end

    def fetch(url, limit = 10)
      raise ArgumentError.new("Too many HTTP redirects") if limit <= 0

      uri = URI(url)
      Net::HTTP.start(
        uri.hostname, uri.port, use_ssl: uri.scheme == "https"
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "image/*"
        http.request(request) do |response|
          process_response(response, limit)
        end
      end
    end

    def process_response(response, limit)
      case response
      when Net::HTTPSuccess
        process_http_success(response)
      when Net::HTTPRedirection
        fetch(response["location"], limit - 1)
      else
        raise("Unexpected response type: #{response.value}")
      end
    end

    def process_http_success(response)
      @temp_file = Tempfile.new("api_upload")
      File.open(@temp_file, "w:utf-8") do |fh|
        response.read_body do |chunk|
          fh.write(chunk.force_encoding("utf-8"))
        end
      end
      self.content        = @temp_file
      self.content_length = response["Content-Length"].to_i
      self.content_type   = response["Content-Type"].to_s
      self.content_md5    = response["Content-MD5"].to_s
    end

    def clean_up
      File.delete(@temp_file) if @temp_file
    end
  end

  # Class encapsulating an upload from a file stored locally on the server
  class UploadFromFile < Upload
    def initialize(file)
      raise FileMissing.new(file) unless File.exist?(file)

      self.content = File.open(file, "rb")
      self.content_length = File.size(file)
      self.content_type = `file --mime -b #{file}`.sub(/[;\s].*/, "")
    end
  end

  # Class encapsulating an upload sent as an attachement to the HTTP request
  class UploadFromHTTPRequest < Upload
    def initialize(upload)
      self.content        = upload.data
      self.content_length = upload.length
      self.content_type   = upload.content_type
      self.content_md5    = upload.checksum
    end
  end
end
