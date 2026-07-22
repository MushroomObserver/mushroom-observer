# frozen_string_literal: true

# Weekly tripwire (#4859): directly checks recently-uploaded gps_hidden
# originals on the image server(s) for GPS tags that survived the strip
# pipeline. Alert-only -- a hit means a #4858-class mechanism is back and
# needs investigating, not silent auto-fixing. The 14-day window with a
# weekly schedule scans every image at least once after its transfer has
# settled (untransferred images are skipped here; their originals are
# still local, a window the transfer/stale-files pipeline owns, and they
# land in next week's run).
class GpsLeakDetectorJob < ApplicationJob
  queue_as(:maintenance)

  WINDOW = 14.days

  def perform
    images = candidates
    return log("No recent gps_hidden images to check") if images.empty?

    hit_ids = Image::Processor.detect_gps_leaks(images) { |msg| log(msg) }
    if hit_ids.empty?
      log("Checked #{images.size} recent gps_hidden image(s): clean")
    else
      alert("#{hit_ids.size} gps_hidden image(s) still carry GPS on the " \
            "image server (see issue #4859 for the known mechanisms and " \
            "remediation tooling): ids #{hit_ids}")
    end
  end

  private

  def candidates
    Image.joins(observation_images: :observation).
      where(observations: { gps_hidden: true }).
      where(transferred: true).
      where(created_at: WINDOW.ago..).
      distinct.to_a
  end
end
