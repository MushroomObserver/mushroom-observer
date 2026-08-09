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
    FieldSlipExtract.record(
      image: image, user: user, result: result,
      prompt_version: FieldSlip::Extractor::PROMPT_VERSION
    )
  rescue StandardError => e
    FieldSlipExtract.fail!(image: image, user: user, error: e.message)
  end
end
