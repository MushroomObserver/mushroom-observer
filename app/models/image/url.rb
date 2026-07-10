# frozen_string_literal: true

class Image
  class URL
    SUBDIRECTORIES = {
      full_size: "orig",
      huge: "1280",
      large: "960",
      medium: "640",
      small: "320",
      thumbnail: "thumb"
    }.freeze

    SUBDIRECTORY_TO_SIZE = {
      "orig" => :full_size,
      "1280" => :huge,
      "960" => :large,
      "640" => :medium,
      "320" => :small,
      "thumb" => :thumbnail
    }.freeze

    PLACEHOLDER_URLS = {
      thumbnail: "/place_holder_thumb.jpg",
      small: "/place_holder_320.jpg"
    }.freeze

    # Resized copies are always converted to jpg, but the original file
    # (served by the fallback tier below, before any resize exists yet)
    # may still be in whatever format it was uploaded as. Browsers can't
    # render most of those directly.
    BROWSER_SAFE_EXTENSIONS = %w[jpg jpeg gif png].freeze

    attr_accessor :size, :id, :transferred, :extension, :original_extension
    attr_writer :original_fallback_allowed

    def initialize(args)
      size = args[:size]
      size = SUBDIRECTORY_TO_SIZE[size] unless size.is_a?(Symbol)
      size = :full_size if size == :original
      self.size               = size
      self.id                 = args[:id]
      self.transferred        = args[:transferred]
      self.extension          = args[:extension]
      self.original_extension = args[:original_extension]
      # A Proc (evaluated lazily, only if this fallback tier is actually
      # reached -- it may run a query) or a plain boolean.
      self.original_fallback_allowed = args.fetch(:original_fallback_allowed,
                                                  false)
    end

    def url
      source_order.each do |source|
        return source_url(source) if source_exists?(source)
      end
      return original.source_url(:local) if serve_original_instead?

      PLACEHOLDER_URLS[size] || source_url(fallback_source)
    end

    # Nathan's idea (#4735): between upload and background processing
    # finishing, only the original file exists locally -- none of the
    # resized copies do yet. Rather than show a placeholder graphic (or,
    # for sizes with no placeholder, a broken image pointing at a file
    # that doesn't exist on the remote server yet), serve the original
    # directly; the caller's width/height/CSS sizing downscales it visually.
    def serve_original_instead?
      size != :full_size &&
        BROWSER_SAFE_EXTENSIONS.include?(original_extension) &&
        original_fallback_allowed? &&
        original.source_exists?(:local)
    end

    def original_fallback_allowed?
      unless @original_fallback_allowed.respond_to?(:call)
        return @original_fallback_allowed
      end

      @original_fallback_allowed.call
    end

    def original
      @original ||= self.class.new(
        size: :full_size, id: id, transferred: transferred,
        extension: original_extension, original_fallback_allowed: false
      )
    end

    def source_exists?(source)
      spec = format_spec(source, :test)
      case spec
      when :transferred_flag
        transferred
      when /^file:/
        local_file_exists?(spec)
      when /^https?:/
        remote_file_exists?(spec)
      else
        raise("Invalid image source test spec for " \
              "#{source.inspect}: #{spec.inspect}")
      end
    end

    def local_file_exists?(spec)
      File.exist?(full_filepath(spec)[7..])
    end

    def remote_file_exists?(spec)
      url = URI.parse(full_filepath(spec))
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      result = http.request_head(url.path)
      result.code == "200"
    rescue StandardError
      false
    end

    def source_url(source)
      full_filepath(format_spec(source, :read))
    end

    def full_filepath(path)
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
