# frozen_string_literal: true

class Image
  class Processor
    # Builds the {type:, path:, subdirs:} table for every image server
    # `config/image_config.yml` configures with a `:write` target, plus
    # :local (the filesystem MO itself runs on).
    module ServerData
      def self.build(local_images_path, image_subdirs)
        data = {
          local: { type: "file", path: local_images_path,
                   subdirs: image_subdirs }
        }
        MO.image_sources.each do |server, specs|
          next unless specs[:write]

          # NOTE: must use Addressable::URI to get "user@host:port"
          # `authority`.
          parsed = Addressable::URI.parse(format(specs[:write], root: MO.root))
          data[server] = {
            type: parsed.scheme,
            path: write_target_path(parsed),
            subdirs: write_target_subdirs(specs[:sizes], image_subdirs)
          }
        end
        data.freeze
      end

      # rsync/scp need "user@host:/path"; a bare filesystem path needs no
      # host prefix at all.
      def self.write_target_path(parsed)
        return parsed.path if parsed.authority.blank?

        "#{parsed.authority}:#{parsed.path}"
      end

      # `image_config.yml`'s `:sizes:` lists image *sizes* (:thumbnail,
      # :small, ...); IMAGE_SUBDIRS/transfer code deals in subdirectory
      # strings ("thumb", "320", ...). Translate one to the other here so
      # callers only ever compare subdir strings.
      def self.write_target_subdirs(sizes, image_subdirs)
        return image_subdirs unless sizes

        sizes.map do |size|
          Image::URL::SUBDIRECTORIES[size] ||
            raise("Unknown image size in image_config.yml: #{size.inspect}")
        end
      end
    end
  end
end
