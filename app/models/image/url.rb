class Image
  class Url
    SUBDIRECTORIES = {
      full_size: "orig",
      huge: "1280",
      large: "960",
      medium: "640",
      small: "320",
      thumbnail: "thumb"
    }.freeze

    SUBDIRECTORY_TO_SIZE = {
      "orig"  => :full_size,
      "1280"  => :huge,
      "960"   => :large,
      "640"   => :medium,
      "320"   => :small,
      "thumb" => :thumbnail
    }.freeze

    attr_accessor :size, :id, :transferred, :extension

    def initialize(args)
      size = args[:size]
      size = SUBDIRECTORY_TO_SIZE[size] unless size.is_a?(Symbol)
      size = :full_size if size == :original
      self.size        = size
      self.id          = args[:id]
      self.transferred = args[:transferred]
      self.extension   = args[:extension]
    end

    def url
      for source in source_order
        return source_url(source) if source_exists?(source)
      end
      source_url(fallback_source)
    end

    def source_exists?(source)
      spec = format_spec(source, :test)
      case spec
      when :transferred_flag
        transferred
      when /^file:/
        local_file_exists?(spec)
      when /^http:/
        remote_file_exists?(spec)
      when /^https:/
        remote_file_exists?(spec)
      else
        raise "Invalid image source test spec for "\
              "#{source.inspect}: #{spec.inspect}"
      end
    end

    def local_file_exists?(spec)
      File.exist?(file_name(spec)[7..-1])
    end

    def remote_file_exists?(spec)
      url = URI.parse(file_name(spec))
      result = Net::HTTP.new(url.host, url.port).request_head(url.path)
      result.code == 200
    end

    def source_url(source)
      file_name(format_spec(source, :read))
    end

    def file_name(path)
      "#{path}/#{subdirectory}/#{id}.#{extension}"
    end

    def subdirectory
      SUBDIRECTORIES[size] || raise("Invalid size: #{size.inspect}")
    end

    def source_order
      MO.image_precedence[size] || MO.image_precedence[:default]
    end

    def fallback_source
      MO.image_fallback_source
    end

    def format_spec(source, mode)
      spec = specs(source)[mode]
      spec.is_a?(String) ? format(spec, root: MO.root) : spec
    end

    def specs(source)
      MO.image_sources[source] ||
        raise("Missing image source: #{source.inspect}")
    end
  end
end
