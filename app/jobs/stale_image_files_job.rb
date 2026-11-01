# frozen_string_literal: true

# Safety net for the image transfer pipeline (see #4791's target design):
# scans local disk for image files that have sat around longer than they
# should -- a sign TransferImagesJob never ran for them, or ran and
# didn't finish. Never restarts a transfer itself; classifies what it
# finds (#4974) and alerts to #alerts with the remediation that can
# actually work for each state. Deliberately not scoped to the DB's
# `transferred` column -- once a file is confirmed synced everywhere
# it's supposed to be, Verifier deletes it immediately, so any file
# still on disk past the threshold is, by construction, not yet fully
# transferred.
class StaleImageFilesJob < ApplicationJob
  queue_as(:maintenance)

  STALE_THRESHOLD = 1.hour

  def perform
    files_by_id = stale_files_by_id
    return log("No stale image files found") if files_by_id.empty?

    orphaned, unprocessed, untransferred = classify(files_by_id)
    alert_orphaned(orphaned, files_by_id)
    alert_unprocessed(unprocessed)
    alert_untransferred(untransferred)
  end

  private

  # The three states want different remedies (#4974): a file with no
  # Image row can only be deleted; an image whose derivative sizes were
  # never generated needs reprocessing (retrying the transfer does
  # nothing -- Verifier skips images with missing local sizes); only a
  # complete local set is a genuine transfer straggler that the retry
  # command can fix.
  def classify(files_by_id)
    images = Image.where(id: files_by_id.keys).index_by(&:id)
    orphaned = files_by_id.keys - images.keys
    unprocessed, untransferred = images.values.partition do |image|
      missing_local_sizes?(image)
    end
    [orphaned, unprocessed.map(&:id), untransferred.map(&:id)]
  end

  def missing_local_sizes?(image)
    Image::Processor.expected_paths(image).any? do |path|
      !File.exist?("#{Image::Processor.local_images_path}/#{path}")
    end
  end

  def alert_orphaned(ids, files_by_id)
    return if ids.empty?

    files = ids.flat_map { |id| files_by_id[id] }.sort
    alert("#{ids.size} stale image file id(s) have no Image row - " \
          "orphaned files; delete with: FileUtils.rm_f(#{files.inspect})")
  end

  def alert_unprocessed(ids)
    return if ids.empty?

    alert("#{ids.size} image(s) have local files older than " \
          "#{STALE_THRESHOLD.inspect} with derivative sizes missing - " \
          "processing died? Reprocess with: " \
          "#{Image::Processor.reprocess_command(ids)}")
  end

  def alert_untransferred(ids)
    return if ids.empty?

    alert("#{ids.size} image(s) have local files older than " \
          "#{STALE_THRESHOLD.inspect}, still not transferred - retry " \
          "with: #{TransferImagesJob.retry_command(ids)}")
  end

  # Every stale local file eligible for transfer, keyed by the image id
  # parsed from its filename.
  def stale_files_by_id
    kept_locally = Image::URL::SUBDIRECTORIES.values_at(
      *MO.keep_these_image_sizes_local
    )
    stale_subdirs.each_with_object({}) do |subdir, files_by_id|
      next if kept_locally.include?(File.basename(subdir))

      collect_stale_files(subdir, files_by_id)
    end
  end

  def stale_subdirs
    Dir.glob("#{Image::Processor.local_images_path}/*").select do |path|
      File.directory?(path)
    end
  end

  def collect_stale_files(subdir, files_by_id)
    Dir.glob("#{subdir}/*").each do |file|
      next unless File.file?(file) && stale?(file)
      next unless (id = File.basename(file)[/\A\d+/]&.to_i)

      (files_by_id[id] ||= []) << file
    end
  end

  def stale?(file)
    File.mtime(file) < STALE_THRESHOLD.ago
  end
end
