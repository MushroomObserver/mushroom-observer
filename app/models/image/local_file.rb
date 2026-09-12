# frozen_string_literal: true

class Image
  # Resolves the on-disk file behind an image at a given size, when this
  # machine holds one. A resolved image URL is on disk in two different
  # shapes, and both have to be recognized:
  #
  #   "/images/1280/42.jpg?v"   the local source's `read` spec is a WEB
  #                             path, not a filesystem one, so it maps
  #                             onto MO.local_image_files.
  #   "file:///…/42.jpg?v"      other sources (the test env's `remote1`)
  #                             do use a file:// URL.
  #
  # Returns nil when the resolved location is remote or the file is not
  # actually there.
  module LocalFile
    def self.path(image, size)
      path_from_url(image.image_url(size))
    end

    def self.path_from_url(url)
      resolved = url.url.sub(/\?\d+\z/, "")
      path = file_url_path(resolved) || web_path_on_disk(resolved)
      path if path && File.exist?(path)
    end

    def self.file_url_path(resolved)
      return nil unless resolved.start_with?("file://")

      resolved.delete_prefix("file://")
    end

    def self.web_path_on_disk(resolved)
      prefix = MO.image_sources.dig(:local, :read).to_s
      return nil if prefix.blank? || !resolved.start_with?("#{prefix}/")

      File.join(MO.local_image_files, resolved.delete_prefix("#{prefix}/"))
    end
  end
end
