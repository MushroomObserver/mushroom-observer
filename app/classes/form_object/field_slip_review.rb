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
# controller's read a straight lookup against the extract's template.
class FormObject::FieldSlipReview < FormObject::Base
  Row = Data.define(:field, :extracted, :current, :confidence, :savable,
                    :editable, :role) do
    # Nothing to decide when the model read nothing.
    def blank? = extracted.to_s.strip.empty?

    # Both sides present and different. Marked in the table so the eye
    # lands on it, but NOT unticked -- see `default_use?`.
    def conflict?
      return false if blank? || current.to_s.strip.empty?

      current.to_s.strip != extracted.to_s.strip
    end

    # Everything the model read ticks. Conflicts used to start clear, on
    # the reasoning that applying the form shouldn't overwrite what a
    # person entered -- but on the observations this exists for, the
    # "existing" values are the form's own defaults: today's date, the
    # owner's name as collector, the project's catch-all location (289
    # of project 404's 401 observations sit on it). Guarding those made
    # the common case three clicks per slip to undo defaults nobody
    # chose. Reviewers read every row anyway, and both values stay on
    # screen, so the decision is still in front of them.
    def default_use? = savable && present?

    def name_row? = role == :name
    def location_row? = role == :location
    def inat_row? = role == :inat
    def code_row? = role == :code

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
  # Whether the template's iNat-codes field holds an iNaturalist
  # observation id.
  attribute :inat_code, default: false

  def self.build(extract:, observation:, user: nil)
    template = extract.template
    new(name_known: name_known?(extract, template, user),
        location_suggestion: extract.location_suggestion,
        inat_code: template.inat_code?(
          extract.value_for(template.inat_codes_field)
        ),
        rows: rows_for(extract, template, observation))
  end

  def self.rows_for(extract, template, observation)
    attachable = code_attachable?(extract, template, observation)
    template.fields.map do |field, target|
      code = field == template.code_field
      Row.new(field: field, extracted: extract.value_for(field),
              current: current_value(observation, target),
              confidence: extract.confidence_for(field),
              savable: !target.nil? || (code && attachable),
              editable: !target.nil? || field == template.name_field ||
                        (code && attachable),
              role: role_for(template, field))
    end
  end

  # Ticking the read code applies it. That does something in three
  # cases: the observation has no occurrence (attach the slip), its
  # occurrence carries no field slip -- the state a reflection's
  # Edit-companion is created in -- (attach onto that shared
  # occurrence), or the code names a slip on a DIFFERENT occurrence
  # (merge the two). It does nothing only when the observation's
  # occurrence already holds the slip, so no tick is offered then.
  def self.code_attachable?(extract, template, observation)
    code = extract.value_for(template.code_field).to_s.strip
    return false if code.blank?
    return true if observation.occurrence_id.nil?
    return true if observation.occurrence&.field_slip.nil?

    code_on_other_occurrence?(code, observation)
  end

  # The read code names a slip already sitting on a different
  # occurrence -- ticking it merges the two.
  def self.code_on_other_occurrence?(code, observation)
    slip = FieldSlip.find_by(code: code.upcase)
    slip&.occurrence.present? &&
      slip.occurrence.id != observation.occurrence_id
  end

  def self.role_for(template, field)
    case field
    when template.code_field then :code
    when template.name_field then :name
    when template.location_field then :location
    when template.inat_codes_field then :inat
    end
  end

  # Asks the resolver the same question saving will: would proposing
  # this right now succeed without a create-the-name round-trip? Pure
  # lookup -- the resolver only creates on an explicit approved_name.
  def self.name_known?(extract, template, user)
    return false unless user

    given = extract.value_for(template.name_field).to_s.strip
    return false if given.blank?

    resolver = Naming::NameResolver.new(user, given_name: given)
    resolver.success && resolver.name.present?
  end

  # What the observation holds today for the column or notes key this
  # slip field maps to. nil for the review-only fields.
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
