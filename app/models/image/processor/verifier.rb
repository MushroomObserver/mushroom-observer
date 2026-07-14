# frozen_string_literal: true

require("open3")

class Image
  class Processor
    # Transfers and confirms an explicit set of images onto every configured
    # image server, instead of scanning every file on every server. See
    # GitHub issue #4791: a full local+remote tree scan (the original
    # script/verify_images design) is too slow to schedule frequently, and
    # the blind `find -mmin +N | rsync --remove-source-files` cron it was
    # replaced by races Image::Processor#process outright -- it can delete a
    # locally-complete original before the derived sizes are ever generated,
    # with no idea any of that is still in flight.
    #
    # Driven by an explicit list of images (see TransferImagesJob), not a
    # DB scan -- checks presence + byte-size of every expected file
    # directly (no directory listing), uploads anything missing/mismatched
    # on a server that should have it, and only once every size is
    # confirmed present and byte-matching everywhere:
    #   - deletes the local copy of any size not in
    #     MO.keep_these_image_sizes_local
    #   - marks the image transferred
    #
    # Re-checking an already-transferred image for drift (the exact #4791
    # failure mode) is NOT this class's job -- once local copies are
    # deleted, there's no local byte count left to compare a remote file
    # against, so that's a presence check against a full remote listing,
    # not a per-path byte comparison. See Image::Processor::GapDetector.
    class Verifier
      def initialize(&log)
        @log = log
        @uploaded = []
        @deleted = []
        @completed = []
        @failed = []
        # Fetched once per run (not cached at the class level -- see the
        # comment on Image::Processor.local_images_path).
        @image_server_data = Processor.image_server_data
        @image_servers = @image_server_data.keys - [:local]
      end

      def transfer(images)
        images.find_each { |image| transfer_image(image) }
        { uploaded: @uploaded, deleted: @deleted, completed: @completed,
          failed: @failed }
      end

      private

      def transfer_image(image)
        paths = paths_for(image)
        local_sizes = paths.index_with { |path| local_size(path) }
        # Still mid-#process (a size hasn't been generated locally yet) --
        # nothing to verify or transfer until it exists. Not an error: this
        # is the normal in-progress window between upload and job
        # completion, exactly the window #4791's race used to exploit.
        return if local_sizes.value?(nil)

        remote_sizes = @image_servers.index_with do |server|
          remote_sizes_for(server, paths_for_server(server, paths))
        end

        upload_mismatches(image, paths, local_sizes, remote_sizes)
        return unless all_synced?(paths, local_sizes, remote_sizes)

        delete_local_copies(image, paths)
        mark_transferred(image)
      end

      def paths_for(image)
        paths = Image::URL::SUBDIRECTORIES.values.map do |subdir|
          "#{subdir}/#{image.id}.jpg"
        end
        ext = image.original_extension
        paths << "orig/#{image.id}.#{ext}" if ext != "jpg"
        paths
      end

      def paths_for_server(server, paths)
        subdirs = @image_server_data[server][:subdirs]
        paths.select { |path| subdirs.include?(subdir_of(path)) }
      end

      def local_size(path)
        full = "#{Processor.local_images_path}/#{path}"
        File.exist?(full) ? File.size(full) : nil
      end

      def remote_sizes_for(server, paths)
        return {} if paths.empty?

        data = @image_server_data[server]
        case data[:type]
        when "file"
          paths.index_with { |path| remote_file_size(data[:path], path) }
        when "ssh"
          ssh_sizes(server, data[:path], paths)
        else
          raise("Don't know how to check #{server} via: #{data[:type]}")
        end
      end

      def remote_file_size(root, path)
        full = "#{root}/#{path}"
        File.exist?(full) ? File.size(full) : nil
      end

      # One ssh round trip per (image, server) -- checks every expected
      # file for this one image in a single call, instead of listing the
      # whole subdirectory (too slow to run often, see #4791) or shelling
      # out once per file (too chatty against a remote host to schedule
      # frequently either). `-L` follows symlinks; `-printf` gives us
      # "path\tsize" lines with no shell quoting to parse around, matching
      # the original script/bash_images' read_server_directory approach.
      def ssh_sizes(server, remote_path, paths)
        host, root = remote_path.split(":", 2)
        full_paths = paths.map { |path| "#{root}/#{path}" }
        output, error, status = Open3.capture3(
          "ssh", host, "find", "-L", *full_paths, "-maxdepth", "0",
          "-printf", "%p\\t%s\\n"
        )
        if connection_failed?(status, error)
          log("Failed to check #{host} for #{server}: #{error}")
        end
        parse_find_output(output, root)
      end

      # `find` exits non-zero (writing "No such file or directory" to
      # stderr per missing path) whenever ANY requested path is missing --
      # the routine, expected outcome for an image not yet on this server,
      # not a failure. Only treat this as a real failure if stderr says
      # something else (ssh-level connection/auth/command errors) --
      # otherwise this logs on nearly every routine check, since a mix of
      # present/missing sizes is the normal case this method exists to
      # detect.
      def connection_failed?(status, error)
        return false if status.success?

        error.lines.any? { |line| line.exclude?("No such file or directory") }
      end

      def parse_find_output(output, root)
        output.each_line.with_object({}) do |line, sizes|
          full_path, size = line.chomp.split("\t")
          next if full_path.blank?

          sizes[full_path.delete_prefix("#{root}/")] = size.to_i
        end
      end

      def upload_mismatches(image, paths, local_sizes, remote_sizes)
        @image_servers.each do |server|
          paths_for_server(server, paths).each do |path|
            next if remote_sizes[server][path] == local_sizes[path]

            upload_one_file(image, server, path)
          end
        end
      end

      # One file's transfer failing (returned false, or raised -- e.g.
      # a missing rsync binary or Errno::ENOENT) must not abort the rest
      # of the run: every other mismatched file still needs its chance
      # to upload.
      def upload_one_file(image, server, path)
        log("Uploading #{path} to #{server}")
        if FileTransfer.copy_file_to_server(server, path)
          @uploaded << [image.id, server, path]
        else
          @failed << [image.id, server, path]
          log("Failed to upload #{path} to #{server}")
        end
      rescue StandardError => e
        @failed << [image.id, server, path]
        log("Failed to upload #{path} to #{server}: #{e.message}")
      end

      # Deliberately checks against the PRE-upload remote_sizes snapshot --
      # a file just uploaded above isn't re-verified in the same run before
      # being trusted; it waits for the next run's fresh remote check. That
      # keeps a routine upload failure and a routine "just fixed it" both
      # inconclusive here (safe either way: nothing gets deleted or marked
      # transferred on unverified data).
      #
      # `[].all?` is vacuously true -- guard against @image_servers being
      # empty (development's :mycolab has no :write target, so
      # ServerData.build excludes it), or every image would be treated as
      # fully synced and deleted locally with nothing actually transferred.
      def all_synced?(paths, local_sizes, remote_sizes)
        return false if @image_servers.empty?

        @image_servers.all? do |server|
          paths_for_server(server, paths).all? do |path|
            remote_sizes[server][path] == local_sizes[path]
          end
        end
      end

      def delete_local_copies(image, paths)
        paths.each do |path|
          next if keep_local?(subdir_of(path))

          full = "#{Processor.local_images_path}/#{path}"
          next unless File.exist?(full)

          log("Deleting #{path}")
          File.delete(full)
          @deleted << [image.id, path]
        end
      end

      def mark_transferred(image)
        return if image.transferred

        image.update(transferred: true)
        Observation.joins(:observation_images).
          where(observation_images: { image_id: image.id }).touch_all
        @completed << image.id
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
