# frozen_string_literal: true

# Pass one of the QR-miss fallback. When DetectFieldSlipQRJob decoded a
# QR but not a slip code -- a DNA-sticker code, say -- the photo still
# holds a slip zbar could not read. This reads the printed code off it
# with the model (FieldSlip::Extractor#read_slip_code, a small,
# template-free call), attaches the slip that code names, and hands off
# to ExtractFieldSlipJob for the full, correctly-templated read. Two
# model calls, but only on photos that already showed a QR, so the
# volume stays small.
class ResolveFieldSlipCodeJob < ApplicationJob
  queue_as :default

  def perform(observation_id, image_id, user_id)
    observation = Observation.find_by(id: observation_id)
    image = Image.find_by(id: image_id)
    user = User.find_by(id: user_id)
    return unless observation && image && user
    return unless observation.occurrence_id.nil?
    return if FieldSlipExtract.exists?(image_id: image.id)

    resolve(observation, image, user)
  rescue StandardError => e
    # Logged, not re-raised: a provider hiccup here should not wedge the
    # job. The collector can still scan the slip by hand.
    Rails.logger.error(
      "ResolveFieldSlipCodeJob failed on image #{image_id}: " \
      "#{e.class}: #{e.message}"
    )
  end

  private

  def resolve(observation, image, user)
    code = FieldSlip::Extractor.default.read_slip_code(image)
    return if code.blank?

    result = FieldSlip::Attacher.attach(observation: observation,
                                        code: code, user: user)
    Rails.logger.info(
      "ResolveFieldSlipCodeJob: read code #{code} -> #{result} " \
      "(observation #{observation.id}, image #{image.id})"
    )
    return unless result == :attached

    ExtractFieldSlipJob.request(image: image, user: user)
  end
end
