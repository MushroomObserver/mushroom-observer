class Image
  class Url
    SUBDIRECTORIES = {
      :original  => 'orig',
      :full_size => 'orig',
      :huge      => '1280',
      :large     => '960',
      :medium    => '640',
      :small     => '320',
      :thumbnail => 'thumb'
    }

    attr_accessor :size, :id, :transferred, :extension

    def initialize(args)
      self.size        = args[:size]
      self.id          = args[:id]
      self.transferred = args[:transferred]
      self.extension   = args[:extension]
    end

    def url
      for source in source_order
        return source_url(source) if source_exists?(source)
      end
      return source_url(fallback_source)
    end

    def source_exists?(source)
      spec = specs(source)[:test]
      case spec
      when :transferred_flag
        transferred
      when /^file:/
        path = spec[7..-1]
        local_file_exists?(path)
      when /^http:/
        remote_file_exists?(url=spec)
      else
        raise "Invalid image source test spec for #{source.inspect}: #{spec.inspect}"
      end
    end

    def local_file_exists?(path)
      File.exists?(file_name(path))
    end

    def remote_file_exists?(url)
      url = URI.parse(url)
      result = Net::HTTP.new(url.host, url.port).request_head(url.path)
      result.code == 200
    end

    def source_url(source)
      spec = specs(source)[:read]
      file_name(spec)
    end

    def file_name(root)
      "#{root}/#{subdirectory}/#{id}.#{extension}"
    end

    def subdirectory
      SUBDIRECTORIES[size] or raise "Invalid size: #{size.inspect}"
    end

    def source_order
      IMAGE_PRECEDENCE[size] || IMAGE_PRECEDENCE[:default]
    end

    def fallback_source
      FALLBACK_SOURCE
    end

    def specs(source)
      IMAGE_SOURCES[source] or raise "Missing image source: #{source.inspect}"
    end
  end
end
