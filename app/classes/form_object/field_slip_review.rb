# frozen_string_literal: true

# One reviewer's pass over a machine-read field slip (see
# FieldSlipExtract). Each row pairs what the model read with what the
# observation currently holds, so the form can show both and the
# reviewer decides per field.
#
# `use`/`value` submit as top-level param hashes keyed by the slip's own
# field labels rather than under this object's namespace: the labels are
# the extract's keys ("Field Slip Code", "MycoMap Voucher Number"), not
# attributes of anything, and keying the params by them keeps the
# controller's read a straight lookup against `Extractor::FIELDS`.
class FormObject::FieldSlipReview < FormObject::Base
  Row = Data.define(:field, :extracted, :current, :confidence, :savable) do
    # Nothing to decide when the model read nothing.
    def blank? = extracted.to_s.strip.empty?

    # A real disagreement -- both sides present and different. This is
    # what makes the row default to OFF: applying it would overwrite
    # something a person already entered.
    def conflict?
      return false if blank? || current.to_s.strip.empty?

      current.to_s.strip != extracted.to_s.strip
    end

    def default_use? = savable && present? && !conflict?
  end

  attribute :rows, default: -> { [] }

  def self.build(extract:, observation:)
    new(rows: FieldSlip::Extractor::FIELDS.map do |field, target|
      Row.new(field: field, extracted: extract.value_for(field),
              current: current_value(observation, target),
              confidence: extract.confidence_for(field),
              savable: !target.nil?)
    end)
  end

  # What the observation holds today for the column or notes key this
  # slip field maps to. nil for the two review-only fields.
  def self.current_value(observation, target)
    return nil if target.nil?

    key = target.to_s
    return observation.notes.to_h[key.delete_prefix("notes.").to_sym] if
      key.start_with?("notes.")

    observation.send(target == :place_name ? :where : target)
  end

  def rows_to_show = rows.compact_blank
end
