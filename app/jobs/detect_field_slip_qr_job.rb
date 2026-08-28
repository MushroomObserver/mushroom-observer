# frozen_string_literal: true

# Scans one newly attached photo for a field slip QR code and, when it
# names a slip the observation can take, attaches it (see
# FieldSlip::QRDecoder and FieldSlip::Attacher). One job per photo (see
# ObservationImage), so a multi-photo upload costs one scan per image;
# once any photo attaches the slip, the rest no-op on the occurrence
# check.
#
# This restores the scan-first flow's automatic project filing for
# photo-first observations: DBG-style voucher slips (#5024) encode only
# the bare code, which a phone's camera app can't act on, so the first
# place MO ever sees the code may be the uploaded photo itself.
class DetectFieldSlipQRJob < ApplicationJob
  queue_as :default

  def perform(observation_id, image_id)
    observation = Observation.find_by(id: observation_id)
    image = Image.find_by(id: image_id)
    return unless observation && image && observation.occurrence_id.nil?
    return unless FieldSlip::QRDecoder.available?

    reading = FieldSlip::QRDecoder.reading(image)
    if reading.slip_code
      attach_and_read(observation, image, reading.slip_code)
    elsif reading.qr_present
      # zbar decoded a QR but not a slip code (a DNA-sticker code, say):
      # the photo still holds a slip it could not read, so hand off to
      # the model-based read (see ResolveFieldSlipCodeJob).
      escalate(observation, image)
    end
  end

  private

  def attach_and_read(observation, image, code)
    result = FieldSlip::Attacher.attach(observation: observation,
                                        code: code, user: observation.user)
    Rails.logger.info(
      "DetectFieldSlipQRJob: #{code} -> #{result} " \
      "(observation #{observation.id}, image #{image.id})"
    )
    return unless result == :attached

    # This image just proved itself to be a slip photo, so read it now
    # -- the ~15s provider call runs while the collector is still
    # photographing, and the review page finds the extract waiting.
    # Chained only on a fresh attach: adding more photos to an already-
    # linked observation never re-reads a slip somebody may have
    # reviewed (those runs exit above on the occurrence check).
    ExtractFieldSlipJob.request(image: image, user: observation.user)
  end

  def escalate(observation, image)
    ResolveFieldSlipCodeJob.perform_later(observation.id, image.id,
                                          observation.user_id)
  end
end
