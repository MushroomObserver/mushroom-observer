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
      include RemoteFiles

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

        remote_sizes = remote_snapshot(paths)
        # Re-read the servers after uploading: a file just pushed here must
        # be confirmed present by an independent `find` before its local
        # copy is deleted. Without the re-read, all_synced? compares against
        # the pre-upload snapshot and can never confirm a first-time upload,
        # so the image sits uploaded-but-unmarked forever -- nothing
        # schedules a second pass (TransferImagesJob runs once per image).
        uploaded = upload_mismatches(image, paths, local_sizes, remote_sizes)
        remote_sizes = remote_snapshot(paths) if uploaded
        return unless all_synced?(paths, local_sizes, remote_sizes)

        delete_local_copies(image, paths)
        mark_transferred(image)
      end

      def remote_snapshot(paths)
        @image_servers.index_with do |server|
          remote_sizes_for(server, paths_for_server(server, paths))
        end
      end

      def paths_for(image)
        paths = Image::URL::SUBDIRECTORIES.values.map do |subdir|
          "#{subdir}/#{image.id}.jpg"
        end
        ext = image.original_extension
        paths << "orig/#{image.id}.#{ext}" if ext != "jpg"
        paths
      end

      def local_size(path)
        full = "#{Processor.local_images_path}/#{path}"
        File.exist?(full) ? File.size(full) : nil
      end

      # Uploads every path whose remote size doesn't match local. Returns
      # true if it attempted any upload, so the caller knows to re-read the
      # servers before trusting all_synced? (see transfer_image).
      def upload_mismatches(image, paths, local_sizes, remote_sizes)
        attempted = false
        @image_servers.each do |server|
          paths_for_server(server, paths).each do |path|
            next if remote_sizes[server][path] == local_sizes[path]

            attempted = true
            upload_one_file(image, server, path)
          end
        end
        attempted
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

      # Checks against a snapshot taken AFTER any upload in this run
      # (transfer_image re-reads the servers when it uploaded anything), so
      # a first-time upload is confirmed by an independent `find` on the
      # server before its local copy is deleted -- not trusted on the
      # uploader's own say-so. A silently-failed upload shows as still
      # missing here and is safely left unmarked.
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

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
