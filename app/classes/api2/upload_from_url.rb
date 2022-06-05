# frozen_string_literal: true

# API2
class API2
  # Class encapsulating an upload from a remote server
  class UploadFromURL < Upload
    def initialize(url)
      super()
      fetch(url)
    rescue StandardError => e
      raise(CouldntDownloadURL.new(url, e))
    end

    def fetch(url, limit = 10)
      raise(ArgumentError.new("Too many HTTP redirects")) if limit <= 0

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
end
