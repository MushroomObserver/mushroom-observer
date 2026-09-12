# frozen_string_literal: true

# Machine-reads one field slip photo in the background (see
# FieldSlip::Extractor), so the ~15-second provider call runs while the
# collector is still photographing instead of behind a spinner. The
# review page shows the extract's status: pending while this runs,
# failed (with the error and a retry button) if the provider chokes,
# the review form once `record` lands.
class ExtractFieldSlipJob < ApplicationJob
  queue_as :default

  # The one entry point: writes the pending row first, so the review
  # page has a status to show from the moment the job is queued.
  def self.request(image:, user:)
    FieldSlipExtract.start!(image: image, user: user)
    perform_later(image.id, user.id)
  end

  def perform(image_id, user_id)
    image = Image.find_by(id: image_id)
    user = User.find_by(id: user_id)
    return unless image && user

    extract(image, user)
  end

  private

  def extract(image, user)
    context = FieldSlip::Extractor::Context.for_image(image)
    result = FieldSlip::Extractor.default.extract(image, context: context)
    extract = FieldSlipExtract.record(
      image: image, user: user, result: result,
      prompt_version: FieldSlip::Extractor::PROMPT_VERSION
    )
    attach_read_code(image, user, extract)
    extract
  rescue StandardError => e
    # Not re-raised -- the failed extract row IS the retry mechanism
    # (the review page's Try Again button) -- so the details have to be
    # logged here or they exist nowhere.
    Rails.logger.error(
      "ExtractFieldSlipJob failed on image #{image.id}: " \
      "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    )
    FieldSlipExtract.fail!(image: image, user: user, error: e.message)
  end

  # The read code is the fallback when the QR path missed: zbar failed
  # to decode ~27% of the CMS fair's slip photos while the extraction
  # read the printed code off nearly all of them -- and without this,
  # the code the extraction knows goes nowhere. Attacher's own guards
  # keep it safe for a background act: never an observation that has a
  # slip, never somebody else's slip.
  def attach_read_code(image, user, extract)
    observation = sole_slipless_observation(image)
    return unless observation

    code = extract.value_for(extract.template.code_field).to_s.strip
    return if code.blank?

    result = FieldSlip::Attacher.attach(observation: observation,
                                        code: code, user: user)
    Rails.logger.info(
      "ExtractFieldSlipJob: read code #{code} -> #{result} " \
      "(observation #{observation.id}, image #{image.id})"
    )
  end

  # An image on several observations makes "whose slip is this?"
  # ambiguous, and a background guess would consume the slip for the
  # right one. Only the review's human decides those.
  def sole_slipless_observation(image)
    observations = image.observations.to_a
    return unless observations.one?

    observation = observations.first
    observation if observation.occurrence_id.nil?
  end
end
