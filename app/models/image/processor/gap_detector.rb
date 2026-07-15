# frozen_string_literal: true

require("open3")

class Image
  class Processor
    # Incremental reconciliation pass (see #4791's target design, part 4):
    # verifies that recently-transferred images actually have all their
    # derived renditions on the image server(s), and regenerates any that
    # are missing. Unlike Verifier (which works a transferred=false
    # work-list at transfer time), this re-checks already-transferred
    # images -- the #4791 "trust but verify the transferred flag" pass.
    #
    # Scoped by ImageGapCheckpoint so each run only examines images past
    # the last-verified id (and old enough for their transfer to have
    # settled), then advances the checkpoint -- a clean image is never
    # re-scanned. Only the five derived sizes are checked: the original is
    # moved to archive storage after a while, so a missing `orig` is
    # expected, not a gap.
    class GapDetector
      # Derived sizes only -- never `orig` (see class comment).
      DERIVED_SUBDIRS = (Image::URL::SUBDIRECTORIES.values - ["orig"]).freeze

      # An image is only re-checked once it is at least this old, so a
      # transfer still in flight isn't mistaken for a gap.
      SETTLE_WINDOW = 1.day

      def initialize(&log)
        @log = log
        @gaps = []
        @regenerated = []
        @unregenerable = []
        @image_server_data = Processor.image_server_data
        @image_servers = @image_server_data.keys - [:local]
      end

      # Pass an explicit relation to scope a run (tests, one-off repairs);
      # such runs do NOT advance the checkpoint. The default scheduled run
      # uses the checkpoint window and advances it.
      def run(images = nil)
        scope = images || default_scope
        find_gaps(scope).each do |image, server, path|
          handle_gap(image, server, path)
        end
        advance_checkpoint(scope) if images.nil?
        { gaps: @gaps, regenerated: @regenerated,
          unregenerable: @unregenerable }
      end

      private

      def default_scope
        Image.where(transferred: true).
          where(Image.arel_table[:id].gt(
                  ImageGapCheckpoint.last_verified_image_id
                )).
          where(Image.arel_table[:created_at].lt(SETTLE_WINDOW.ago))
      end

      def find_gaps(images)
        gaps = []
        images.find_each do |image|
          paths = paths_for(image)
          @image_servers.each do |server|
            server_paths = paths_for_server(server, paths)
            remote = remote_sizes_for(server, server_paths)
            server_paths.each do |path|
              gaps << [image, server, path] if remote[path].nil?
            end
          end
        end
        gaps
      end

      def paths_for(image)
        DERIVED_SUBDIRS.map { |subdir| "#{subdir}/#{image.id}.jpg" }
      end

      def paths_for_server(server, paths)
        subdirs = @image_server_data[server][:subdirs]
        paths.select { |path| subdirs.include?(subdir_of(path)) }
      end

      # Sizes of the given paths that actually exist on the server; a
      # missing path is absent (ssh) or nil (file), so callers check
      # `[path].nil?`. Mirrors Verifier's targeted check -- kept here
      # rather than extracted to avoid touching that reviewed class.
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

      def ssh_sizes(server, remote_path, paths)
        host, root = remote_path.split(":", 2)
        full_paths = paths.map { |path| "#{root}/#{path}" }
        output, error, status = Open3.capture3(
          "ssh", host, "find", "-L", *full_paths, "-maxdepth", "0",
          "-printf", "%p\\t%s\\n"
        )
        if connection_failed?(status, error)
          log("Failed to check #{host} for #{server}: #{error.strip}")
        end
        parse_find_output(output, root)
      end

      # A non-zero find exit is expected when some paths are simply missing
      # ("No such file or directory"); only other stderr is a real
      # connection/command failure.
      def connection_failed?(status, error)
        return false if status.success?

        error.lines.any? { |line| line.exclude?("No such file or directory") }
      end

      def parse_find_output(output, root)
        output.each_line.with_object({}) do |line, files|
          full, size = line.chomp.split("\t")
          next if full.blank?

          files[full.delete_prefix("#{root}/")] = size.to_i
        end
      end

      def subdir_of(path)
        path.split("/", 2).first
      end

      def handle_gap(image, server, path)
        @gaps << [image.id, server, path]
        log("GAP: image #{image.id} missing #{path} on #{server}")
        regenerate(image)
      end

      # Regenerates every derivative size from the original (see
      # Image::Processor#process -- SIZE_CONVERSIONS chains each size from
      # the next-larger one, so anything short of the original cascades
      # back to it anyway), then hands off to Verifier to push whatever's
      # missing and clean up. One attempt per image per run; further gaps
      # on the same image are still recorded but don't retry regeneration.
      # If the original is unavailable (e.g. already archived), the fetch
      # raises and the image is recorded as unregenerable.
      def regenerate(image)
        return if attempted?(image)

        regenerate_and_retransfer(image)
        @regenerated << image.id
      rescue StandardError => e
        @unregenerable << image.id
        log("Could not regenerate image #{image.id}: #{e.message}")
      end

      def attempted?(image)
        @regenerated.include?(image.id) || @unregenerable.include?(image.id)
      end

      def regenerate_and_retransfer(image)
        processor = Image::Processor.new(image: image)
        processor.make_sure_we_have_full_size_locally
        processor.process
        Verifier.new(&@log).transfer(Image.where(id: image.id))
      end

      # Advance the mark past everything examined and verified/regenerated,
      # but hold below the lowest image we couldn't repair so it keeps
      # being re-checked (and re-alerted) next run.
      def advance_checkpoint(scope)
        max_id = scope.maximum(:id)
        return unless max_id

        ceiling = @unregenerable.min ? @unregenerable.min - 1 : max_id
        ImageGapCheckpoint.advance_to(ceiling)
      end

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
