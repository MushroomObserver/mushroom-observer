# frozen_string_literal: true

# Scans a slip-less observation's photos for a field slip QR code and,
# when one names a slip the observation can take, attaches it (see
# FieldSlip::QRDecoder and FieldSlip::Attacher).
#
# This restores the scan-first flow's automatic project filing for
# photo-first observations: DBG-style voucher slips (#5024) encode only
# the bare code, which a phone's camera app can't act on, so the first
# place MO ever sees the code may be the uploaded photo itself.
class DetectFieldSlipQRJob < ApplicationJob
  queue_as :default

  def perform(observation_id)
    observation = Observation.find_by(id: observation_id)
    return unless observation && observation.occurrence_id.nil?
    return unless FieldSlip::QRDecoder.available?

    observation.images.order(:id).each do |image|
      break if attach(observation, image) == :attached
    end
  end

  private

  def attach(observation, image)
    code = FieldSlip::QRDecoder.slip_code_in(image)
    return nil unless code

    result = FieldSlip::Attacher.attach(observation: observation,
                                        code: code, user: observation.user)
    Rails.logger.info(
      "DetectFieldSlipQRJob: #{code} -> #{result} " \
      "(observation #{observation.id}, image #{image.id})"
    )
    result
  end
end
