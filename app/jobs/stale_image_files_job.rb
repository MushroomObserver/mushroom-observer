# frozen_string_literal: true

# Safety net for the image transfer pipeline (see #4791's target design):
# scans local disk for image files that have sat around longer than they
# should -- a sign TransferImagesJob never ran for them, or ran and
# didn't finish. Never restarts a transfer itself; alerts to #alerts with
# the exact command an admin can run to retry. Deliberately not scoped to
# the DB's `transferred` column -- once a file is confirmed synced
# everywhere it's supposed to be, Verifier deletes it immediately, so any
# file still on disk past the threshold is, by construction, not yet
# fully transferred.
class StaleImageFilesJob < ApplicationJob
  queue_as(:maintenance)

  STALE_THRESHOLD = 1.hour

  def perform
    ids = stale_image_ids
    return log("No stale image files found") if ids.empty?

    alert("#{ids.size} image(s) have local files older than " \
          "#{STALE_THRESHOLD.inspect}, still not transferred - retry " \
          "with: TransferImagesJob.perform_now(image_ids: #{ids})")
  end

  private

  def stale_image_ids
    kept_locally = Image::URL::SUBDIRECTORIES.values_at(
      *MO.keep_these_image_sizes_local
    )
    stale_subdirs.flat_map do |subdir|
      next [] if kept_locally.include?(File.basename(subdir))

      stale_ids_in(subdir)
    end.uniq
  end

  def stale_subdirs
    Dir.glob("#{Image::Processor.local_images_path}/*").select do |path|
      File.directory?(path)
    end
  end

  def stale_ids_in(subdir)
    Dir.glob("#{subdir}/*").filter_map do |file|
      next unless File.file?(file) && stale?(file)

      File.basename(file)[/\A\d+/]&.to_i
    end
  end

  def stale?(file)
    File.mtime(file) < STALE_THRESHOLD.ago
  end
end
