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

  # Who may read a slip and review the result: site admins, and the
  # admins of any project the image's observations belong to. A foray's
  # own organizers are exactly the people who can tell whether a slip
  # was transcribed correctly, and they are already trusted with that
  # project's data -- gating on site admin alone would put every foray's
  # transcription through the same few people.
  #
  # Still not open to everyone: each read costs an API call, and a
  # careless one writes to observations the reviewer may not own.
  def self.permitted?(image:, user:, site_admin: false)
    return false unless user
    return true if site_admin

    image.observations.any? do |obs|
      obs.projects.any? { |project| project.is_admin?(user) }
    end
  end

  # An extraction has a lifecycle now that it runs in the background:
  # `start!` writes the pending row (so the review page has something
  # to show while the provider is thinking), `record` completes it,
  # `fail!` keeps the error where the reviewer will actually see it --
  # a failed read used to leave nothing behind but a log line.
  STATUSES = %w[pending complete failed].freeze

  validates :status, inclusion: { in: STATUSES }

  # Replaces any previous read of this image. The provider/model here
  # are what will be asked; `record` overwrites them with what actually
  # answered.
  def self.start!(image:, user:)
    extract = find_or_initialize_by(image_id: image.id)
    extract.update!(user: user, status: "pending", provider: "gemini",
                    model: FieldSlip::Extractor::Gemini::DEFAULT_MODEL,
                    prompt_version: FieldSlip::Extractor::PROMPT_VERSION)
    extract
  end

  # Replaces any previous read of this image.
  def self.record(image:, user:, result:, prompt_version:)
    extract = find_or_initialize_by(image_id: image.id)
    extract.update!(
      user: user, provider: result.provider, model: result.model,
      prompt_version: prompt_version, status: "complete",
      data: { "fields" => result.fields, "confidence" => result.confidence,
              "template" => result.template,
              "slip_present" => result.slip_present,
              "template_matched" => result.template_matched,
              "unreadable" => result.unreadable, "raw" => result.raw }
    )
    extract
  end

  def self.fail!(image:, user:, error:)
    extract = find_or_initialize_by(image_id: image.id)
    extract.user ||= user
    extract.provider ||= "gemini"
    extract.model ||= FieldSlip::Extractor::Gemini::DEFAULT_MODEL
    extract.status = "failed"
    extract.data = extract.data.to_h.merge("error" => error.to_s)
    extract.save!
    extract
  end

  def pending? = status == "pending"
  def failed? = status == "failed"
  def complete? = status == "complete"

  # What went wrong, for the review page's failed state.
  def error = data.to_h["error"]

  def fields = data.to_h["fields"] || {}
  def confidence = data.to_h["confidence"] || {}

  # The layout this photo was read as. Reads stored before templates
  # existed were all of MO's own slip.
  def template
    @template ||= FieldSlip::Template.for(data.to_h["template"] || "mo")
  end

  # True only when the read explicitly reported no slip in the image.
  # Reads stored before the provider reported it answer false, same as
  # a read that did see one -- absence of the flag is not evidence.
  def no_slip? = data.to_h["slip_present"] == false

  # A slip was seen, but printed on a different layout than this
  # project's slips use, so nothing was read off it. Same only-explicit-
  # false reasoning as `no_slip?`.
  def template_mismatch?
    data.to_h["template_matched"] == false && !no_slip?
  end

  # Fields written on the slip that this image could not recover, so
  # another photo of the same slip is worth consulting for them. A
  # field absent from this list and null in `fields` is a box the
  # collector left empty.
  def unreadable = data.to_h["unreadable"] || []
  def unreadable?(slip_field) = unreadable.include?(slip_field)

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
    read = value_for(template.code_field).to_s.strip
    attached = observation&.field_slip&.code.to_s.strip
    return nil if read.blank? || attached.blank? || read == attached

    [read, attached]
  end

  # Location values the project has no alias for -- "EB2" for "Early
  # Bird 2" when the project only knows "2". Worth surfacing: adding the
  # alias fixes this slip and every later one, since the prompt is built
  # from the same table.
  def unknown_location_alias
    written = value_for(template.location_field).to_s.strip
    return nil if written.blank?
    # A full MO location name is not an unknown abbreviation, whether or
    # not the project happens to alias it -- warning about one and
    # offering to define an alias would be telling the reviewer that
    # something MO already knows is unrecognized.
    return nil if Location.exists?(name: written)
    return nil if known_location_names.any? { |n| n.casecmp?(written) }

    written
  end

  # The Location a written abbreviation obviously means, when the
  # project is already using exactly one that matches -- "Fulton, Co"
  # against a project whose observations sit in "Fulton Co.,
  # Pennsylvania, USA". Slips are written by hand in the field, so the
  # county or site is abbreviated far more often than not, and typing
  # the full MO name back in is the slowest part of a review.
  #
  # Deliberately narrow: it matches only against locations THIS project
  # already uses, and only when exactly one of them matches, so a guess
  # can't quietly pick between two plausible sites.
  def location_suggestion
    written = value_for(template.location_field).to_s.strip
    return nil if written.blank?

    matches = project_locations.select do |location|
      normalize_place(location.name).start_with?(normalize_place(written))
    end
    matches.first if matches.one?
  end

  private

  # Punctuation and case are what differ between a hand-written
  # abbreviation and MO's full name; word order and spelling are not.
  def normalize_place(str)
    str.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  # Every location the project is already using -- its observations',
  # its aliases' targets, and its own -- which is a much better
  # candidate set than all of MO.
  def project_locations
    project = observation&.projects&.first
    return [] unless project

    from_observations = Location.joins(:observations).
                        where(observations: { id: project.observations }).
                        distinct.to_a
    aliased = ProjectAlias.where(project: project, target_type: "Location").
              includes(:target).filter_map(&:target)
    (from_observations + aliased + [project.location]).compact.uniq
  end

  def known_location_names
    context = FieldSlip::Extractor::Context.new(observation: observation)
    context.aliases("Location").flatten +
      [observation&.location&.name].compact
  end
end
