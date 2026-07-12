# frozen_string_literal: true

require("open3")

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
          list_subdir(server, data, subdir).each do |name, size|
            files["#{subdir}/#{name}"] = size
          end
        end
      end

      # "file" is a local (or locally-mounted) path -- Dir.glob it directly.
      # "ssh" is a real remote host -- shell out, matching how the original
      # script/bash_images' read_server_directory handled it.
      def list_subdir(server, data, subdir)
        case data[:type]
        when "file"
          list_local_subdir("#{data[:path]}/#{subdir}")
        when "ssh"
          list_ssh_subdir(server, data[:path], subdir)
        else
          raise("Don't know how to list #{server} via: #{data[:type]}")
        end
      end

      def list_local_subdir(path)
        Dir.glob("#{path}/*").each_with_object({}) do |file_path, files|
          next unless File.file?(file_path)

          files[File.basename(file_path)] = File.size(file_path)
        end
      end

      # `data[:path]` for an ssh server is "user@host:/remote/path" (see
      # ServerData.write_target_path) -- split on the first ":" the same
      # way rsync/scp remote-path syntax does. `-L` follows symlinks;
      # `-printf` gives us "name\tsize" lines with no shell quoting to
      # parse around -- both match read_server_directory's ssh branch.
      def list_ssh_subdir(server, remote_path, subdir)
        host, path = remote_path.split(":", 2)
        output, status = Open3.capture2(
          "ssh", host, "find", "-L", "#{path}/#{subdir}", "-maxdepth", "1",
          "-type", "f", "-printf", "%f\\t%s\\n"
        )
        unless status.success?
          log("Failed to list #{host}:#{path}/#{subdir} on #{server}")
          return {}
        end

        parse_find_output(output)
      end

      def parse_find_output(output)
        output.each_line.with_object({}) do |line, files|
          name, size = line.chomp.split("\t")
          files[name] = size.to_i if name.present?
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
            if FileTransfer.copy_file_to_server(server, path)
              @uploaded << [server, path]
            else
              log("Failed to upload #{path} to #{server}")
            end
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
