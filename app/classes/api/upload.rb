# encoding: utf-8

class API
  class Upload
    attr_accessor :data, :length, :content_type, :checksum
    def initialize(args)
      @data = args[:data]
      @length = args[:length]
      @content_type = args[:content_type]
      @checksum = args[:checksum]
    end
  end

  def prepare_upload
    result = nil
    if url = parse_string(:upload_url)
      fail TooManyUploads.new if result
      result = UploadFromURL.new(url)
    end
    if file = parse_string(:upload_file)
      fail TooManyUploads.new if result
      result = UploadFromFile.new(file)
    end
    if upload = parse_upload
      fail TooManyUploads.new if result
      result = UploadFromHTTPRequest.new(upload)
    end
    result
  end

  class Upload
    attr_accessor :content, :content_length, :content_type, :content_md5
    def clean_up; end
  end

  class UploadFromURL < Upload
    def initialize(url)
      @temp_file = Tempfile.new("api_upload")
      uri = URI.parse(url)
      File.open(@temp_file, "w:utf-8") do |fh|
        Net::HTTP.new(uri.host, uri.port).start do |http|
          http.request_get(uri.path) do |response|
            response.read_body do |chunk|
              fh.write(chunk.force_encoding("utf-8"))
            end
            self.content        = @temp_file
            self.content_length = response["Content-Length"].to_i
            self.content_type   = response["Content-Type"].to_s
            self.content_md5    = response["Content-MD5"].to_s
          end
        end
      end
    rescue => e
      raise CouldntDownloadURL.new(url, e)
    end

    def clean_up
      File.delete(@temp_file) if @temp_file
    end
  end

  class UploadFromFile < Upload
    def initialize(file)
      fail FileMissing.new(file) unless File.exist?(file)
      self.content = File.open(file, "rb")
      self.content_length = File.size(file)
      self.content_type = `file --mime -b #{file}`.sub(/[;\s].*/, "")
    end
  end

  class UploadFromHTTPRequest < Upload
    def initialize(upload)
      self.content        = upload.data
      self.content_length = upload.length
      self.content_type   = upload.content_type
      self.content_md5    = upload.checksum
    end
  end
end
