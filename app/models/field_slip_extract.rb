# frozen_string_literal: true

# The latest machine-read of one field slip photo (see
# FieldSlip::Extractor). One row per image: re-extracting replaces the
# previous read, because only the newest is ever reviewed and keeping a
# history would just accumulate rows nobody looks at.
#
# `data` holds the provider's response verbatim alongside the values
# pulled out of it. That is deliberately more than the review form
# needs: stored beside `provider`/`model`/`prompt_version` it records
# how a value was arrived at, which is the part that stays useful once
# the extraction setup has moved on.
class FieldSlipExtract < AbstractModel
  belongs_to :image
  belongs_to :user

  validates :provider, presence: true
  validates :model, presence: true
  validates :image_id, uniqueness: true

  # Replaces any previous read of this image.
  def self.record(image:, user:, result:, prompt_version:)
    extract = find_or_initialize_by(image_id: image.id)
    extract.update!(
      user: user, provider: result.provider, model: result.model,
      prompt_version: prompt_version,
      data: { "fields" => result.fields, "confidence" => result.confidence,
              "raw" => result.raw }
    )
    extract
  end

  def fields = data.to_h["fields"] || {}
  def confidence = data.to_h["confidence"] || {}

  def value_for(slip_field) = fields[slip_field]

  def confidence_for(slip_field)
    level = confidence[slip_field].to_s.downcase
    FieldSlip::Extractor::CONFIDENCE_LEVELS.include?(level) ? level : "low"
  end

  # The observation the reviewed values would be saved to. An image can
  # hang off several; the review form works on one at a time.
  def observation = image.observations.first

  # The printed code the model read, when it disagrees with the slip
  # actually attached to the observation -- the strongest signal that
  # this image is not the slip for this observation. nil when they
  # agree, when either is missing, or when there is no attached slip.
  def code_mismatch
    read = value_for("Field Slip Code").to_s.strip
    attached = observation&.field_slip&.code.to_s.strip
    return nil if read.blank? || attached.blank? || read == attached

    [read, attached]
  end

  # Location values the project has no alias for -- "EB2" for "Early
  # Bird 2" when the project only knows "2". Worth surfacing: adding the
  # alias fixes this slip and every later one, since the prompt is built
  # from the same table.
  def unknown_location_alias
    written = value_for("Location").to_s.strip
    return nil if written.blank?
    return nil if known_location_names.any? { |n| n.casecmp?(written) }

    written
  end

  private

  def known_location_names
    context = FieldSlip::Extractor::Context.new(observation: observation)
    context.aliases("Location").flatten +
      [observation&.location&.name].compact
  end
end
