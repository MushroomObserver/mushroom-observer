# frozen_string_literal: true

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
      include RemoteFiles

      # Derived sizes only -- never `orig` (see class comment).
      DERIVED_SUBDIRS = (Image::URL::SUBDIRECTORIES.values - ["orig"]).freeze

      # An image is only re-checked once it is at least this old, so a
      # transfer still in flight isn't mistaken for a gap.
      SETTLE_WINDOW = 1.day

      # Paths checked per ssh round trip. Batching many images' paths into
      # one `find` keeps a daily run to a handful of round trips instead of
      # one per image; the chunk keeps the argv well under any limit.
      REMOTE_CHECK_BATCH = 500

      def initialize(&log)
        @log = log
        @gaps = []
        @regenerated = []
        @unregenerable = []
        @unchecked = []
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
          unregenerable: @unregenerable, unchecked: @unchecked }
      end

      private

      def default_scope
        Image.where(transferred: true).
          where(Image.arel_table[:id].gt(
                  ImageGapCheckpoint.last_verified_image_id
                )).
          where(Image.arel_table[:created_at].lt(SETTLE_WINDOW.ago))
      end

      # Checks the whole scope against each server in batched ssh round
      # trips (not one per image), returning [image, server, path] for
      # every derived rendition missing on a server that should carry it.
      def find_gaps(images)
        images = images.to_a
        @image_servers.flat_map { |server| gaps_on_server(server, images) }
      end

      def gaps_on_server(server, images)
        image_for = image_by_path(server, images)
        image_for.keys.each_slice(REMOTE_CHECK_BATCH).flat_map do |chunk|
          chunk_gaps(server, chunk, image_for)
        end
      end

      def image_by_path(server, images)
        images.each_with_object({}) do |image, image_for|
          paths_for_server(server, paths_for(image)).each do |path|
            image_for[path] = image
          end
        end
      end

      def chunk_gaps(server, chunk, image_for)
        remote = remote_sizes_for(server, chunk)
        # nil: the check itself failed (see RemoteFiles) -- reporting
        # every path in the chunk as a gap would trigger a mass
        # regeneration + re-upload of files that are actually fine
        # (#4974). Record the images as unchecked instead; the held
        # checkpoint re-examines them next run.
        return record_unchecked(server, chunk, image_for) if remote.nil?

        chunk.filter_map do |path|
          [image_for[path], server, path] if remote[path].nil?
        end
      end

      def record_unchecked(server, chunk, image_for)
        ids = chunk.map { |path| image_for[path].id }.uniq
        @unchecked |= ids
        log("Could not check #{server} - skipping #{ids.size} image(s)")
        []
      end

      def paths_for(image)
        DERIVED_SUBDIRS.map { |subdir| "#{subdir}/#{image.id}.jpg" }
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
      # but hold below the lowest image we couldn't repair -- or couldn't
      # even check -- so it keeps being re-checked (and re-alerted) next
      # run.
      def advance_checkpoint(scope)
        max_id = scope.maximum(:id)
        return unless max_id

        blocked = (@unregenerable + @unchecked).min
        ceiling = blocked ? blocked - 1 : max_id
        ImageGapCheckpoint.advance_to(ceiling)
      end

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
