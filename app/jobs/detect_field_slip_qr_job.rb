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

    code = FieldSlip::QRDecoder.slip_code_in(image)
    return unless code

    result = FieldSlip::Attacher.attach(observation: observation,
                                        code: code, user: observation.user)
    Rails.logger.info(
      "DetectFieldSlipQRJob: #{code} -> #{result} " \
      "(observation #{observation.id}, image #{image.id})"
    )
  end
end
