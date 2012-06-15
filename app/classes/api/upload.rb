# encoding: utf-8

class API
  def prepare_upload
    if url = parse_string(:upload_url)
      UploadFromURL.new(url)
    elsif file = parse_string(:upload_file)
      UploadFromFile.new(file)
    elsif http_request
      UploadFromHTTPRequest.new(http_request)
    else
      nil
    end
  end

  class Upload
    attr_accessor :content, :content_length, :content_type, :content_md5
    def clean_up; end
  end

  class UploadFromURL < Upload
    def initialize(url)
      @temp_file = "#{RAILS_ROOT}/tmp/api_upload.#{$$}"
      uri = URI.parse(url)
      File.open(@temp_file, 'w:utf-8') do |fh|
        Net::HTTP.new(uri.host, uri.port).start do |http|
          http.request_get(uri.request_uri) do |response|
            response.read_body do |chunk|
              fh.write(chunk)
            end
            self.content        = @temp_file
            self.content_length = response['Content-Length'].to_i
            self.content_type   = response['Content-Type'].to_s
            self.content_md5    = response['Content-MD5'].to_s
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
      raise FileMissing.new(file) unless File.exists?(file)
      self.content = file
      self.content_length = File.size(file)
      self.content_type = `file --mime -b #{file}`.sub(/[;\s].*/, '')
    end
  end

  class UploadFromHTTPRequest < Upload
    def initialize(request)
      self.content        = request.body
      self.content_length = request.content_length.to_i
      self.content_type   = request.content_type.to_s
      self.content_md5    = request.headers['Content-MD5'].to_s
    end
  end
end
