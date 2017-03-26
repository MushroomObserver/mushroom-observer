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
      fetch(url)
    rescue => e
      raise CouldntDownloadURL.new(url, e)
    end

    def fetch(url, limit=10)
      raise(ArgumentError, "Too many HTTP redirects") if limit <= 0
      uri = URI(url)
      Net::HTTP.start(uri.hostname, uri.port,
                      :use_ssl => uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "image/*"
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess then
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
          when Net::HTTPRedirection then
            fetch(response['location'], limit-1)
          else
            raise("Unexpected response type: #{response.value}")
          end
        end
      end
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
