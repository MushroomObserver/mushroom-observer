# frozen_string_literal: true

class Image
  class Processor
    # Ruby port of script/verify_images. Lists every local and remote image
    # file (by subdir/filename => byte size), uploads any local file that's
    # missing or mismatched on a server that's supposed to have it, then
    # deletes local copies once they're confirmed to match on every server
    # that carries that subdirectory -- skipping any size configured in
    # MO.keep_these_image_sizes_local, which never gets deleted locally.
    class Verifier
      def initialize(&log)
        @log = log
        @uploaded = []
        @deleted = []
        # Fetched once per run (not cached at the class level -- see the
        # comment on Image::Processor.local_images_path).
        @image_server_data = Processor.image_server_data
        @image_servers = @image_server_data.keys - [:local]
      end

      def run
        listings = build_listings
        upload_mismatches(listings)
        delete_files_no_longer_needed(listings)
        { uploaded: @uploaded, deleted: @deleted }
      end

      private

      def build_listings
        [:local, *@image_servers].index_with { |server| list_server(server) }
      end

      def list_server(server)
        data = @image_server_data[server]
        data[:subdirs].each_with_object({}) do |subdir, files|
          log("Listing #{server} #{subdir}")
          Dir.glob("#{data[:path]}/#{subdir}/*").each do |path|
            next unless File.file?(path)

            files["#{subdir}/#{File.basename(path)}"] = File.size(path)
          end
        end
      end

      def upload_mismatches(listings)
        local = listings[:local]
        @image_servers.each do |server|
          subdirs = @image_server_data[server][:subdirs]
          local.each_key do |path|
            next unless subdirs.include?(subdir_of(path))
            next if listings[server][path] == local[path]

            log("Uploading #{path} to #{server}")
            FileTransfer.copy_file_to_server(server, path)
            @uploaded << [server, path]
          end
        end
      end

      def delete_files_no_longer_needed(listings)
        local = listings[:local]
        local.each_key do |path|
          next if keep_local?(subdir_of(path))
          next unless fully_synced?(path, listings)

          log("Deleting #{path}")
          File.delete("#{Processor.local_images_path}/#{path}")
          @deleted << path
        end
      end

      def fully_synced?(path, listings)
        local_size = listings[:local][path]
        @image_servers.all? do |server|
          subdirs = @image_server_data[server][:subdirs]
          subdirs.exclude?(subdir_of(path)) ||
            listings[server][path] == local_size
        end
      end

      def keep_local?(subdir)
        MO.keep_these_image_sizes_local.any? do |size|
          Image::URL::SUBDIRECTORIES[size] == subdir
        end
      end

      def subdir_of(path)
        path.split("/", 2).first
      end

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
