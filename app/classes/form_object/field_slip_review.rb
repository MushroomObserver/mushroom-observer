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
  Row = Data.define(:field, :extracted, :current, :confidence, :savable,
                    :editable) do
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

    def name_row? = field == FieldSlip::Extractor::NAME_FIELD
    def location_row? = field == FieldSlip::Extractor::LOCATION_FIELD

    # Both get their own labelled section rather than a table cell: an
    # autocompleter only renders its dropdown and hidden id field when
    # it has a real label.
    def own_section? = name_row? || location_row?
  end

  attribute :rows, default: -> { [] }
  # Whether the ID as read already resolves to a Name MO holds. Drives
  # the name tick box: a known name is safe to propose unreviewed, an
  # unknown one is an explicit decision to create something.
  attribute :name_known, default: false
  # The Location the written abbreviation obviously means, when the
  # project is already using exactly one that matches.
  attribute :location_suggestion, default: nil

  def self.build(extract:, observation:, user: nil)
    new(name_known: name_known?(extract, user),
        location_suggestion: extract.location_suggestion,
        rows: FieldSlip::Extractor::FIELDS.map do |field, target|
          Row.new(field: field, extracted: extract.value_for(field),
                  current: current_value(observation, target),
                  confidence: extract.confidence_for(field),
                  savable: !target.nil?,
                  editable: !target.nil? ||
                            field == FieldSlip::Extractor::NAME_FIELD)
        end)
  end

  # Asks the resolver the same question saving will: would proposing
  # this right now succeed without a create-the-name round-trip? Pure
  # lookup -- the resolver only creates on an explicit approved_name.
  def self.name_known?(extract, user)
    return false unless user

    given = extract.value_for(FieldSlip::Extractor::NAME_FIELD).to_s.strip
    return false if given.blank?

    resolver = Naming::NameResolver.new(user, given_name: given)
    resolver.success && resolver.name.present?
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

  def rows_to_show = rows.compact_blank.reject(&:own_section?)

  def name_row = rows.find(&:name_row?)
  def location_row = rows.find(&:location_row?)

  # What to put in the Locality box: the suggested full name when there
  # is one, since accepting it should cost nothing, but the reviewer
  # still sees what the slip actually said in the flag above.
  def location_value
    location_suggestion&.name.presence || location_row&.extracted
  end
end
