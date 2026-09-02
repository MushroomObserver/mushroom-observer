# frozen_string_literal: true

class Inat
  # Standardizes one imported observation's project and field-slip
  # associations against the import's target project (#5259). No-op
  # when the import has no project.
  #
  # Two entry points:
  #
  # `standardize(observation, inat_id:)` runs inline, right after the
  # importer creates the observation. Priority order:
  #
  #   1. iNat-linked native partner: a native (non-reflection)
  #      observation whose notes cite this observation's iNat number
  #      and which carries a field slip is the same physical specimen
  #      scanned at the foray. The import observation joins that
  #      native's occurrence (its correct slip wins); the native stays
  #      primary, since a reflection may not be an occurrence's
  #      primary. A slip already on the import observation yields via
  #      `Occurrence.merge!`.
  #   2. A slip already attached (reused/spare, wrong project): the
  #      slip is reassigned to the target project.
  #   3. A target-prefix code in the notes (the collector wrote the
  #      code in the iNat description): attach it.
  #   4. Otherwise, just add the observation to the project.
  #
  # `reconcile_after_attach(observation)` is the case-2 hook for slips
  # the asynchronous QR scan attaches later (the scan is an
  # `ObservationImage` callback, not part of the import pipeline, so
  # it settles after the inline pass ran).
  #
  # Membership respects the plan's constraint rule: an import run by a
  # project admin adds every observation; anyone else's adds respect
  # the project's constraints, and the observations kept out are
  # recorded on the import for review.
  class ProjectSlipStandardizer
    INAT_REF = %r{(?:observations/|iNat[^0-9]{0,4})(\d{6,})}i

    def self.reconcile_after_attach(observation)
      import = observation.inat_import
      return unless import&.project_id

      new(import).reconcile_slip(observation)
    end

    def initialize(inat_import)
      @import = inat_import
      @project = inat_import.project
      @prefix = @project&.field_slip_prefix.to_s
    end

    def active?
      @project.present?
    end

    def standardize(observation, inat_id:)
      return unless active?

      native = native_partner(observation, inat_id.to_s)
      if native
        link_to_native(observation, native)
      elsif (slip = observation.occurrence&.field_slip)
        reassign_slip(slip)
      elsif (code = notes_slip_code(observation))
        attach_from_notes(observation, code)
      end
      ensure_member(observation)
    end

    # Case 2 for a slip attached after the inline pass (QR scan,
    # review save): move a wrong-project slip to the target project
    # and keep a native member primary.
    def reconcile_slip(observation)
      return unless active?

      slip = observation.occurrence&.field_slip
      return unless slip

      reassign_slip(slip)
      keep_native_primary(observation.occurrence)
      ensure_member(observation)
    end

    private

    # A native observation citing this iNat number in its notes and
    # carrying a field slip. Reflections are excluded -- another
    # import's copy of the same record is not a foray scan.
    def native_partner(observation, inat_id)
      return nil if inat_id.blank?

      Observation.where(Observation[:notes].matches("%#{inat_id}%")).
        where(reflected_at: nil).where.not(id: observation.id).
        includes(occurrence: :field_slip).
        find { |cand| native_match?(cand, inat_id) }
    end

    def native_match?(cand, inat_id)
      cand.occurrence&.field_slip_id &&
        cand.notes.to_s.scan(INAT_REF).flatten.include?(inat_id)
    end

    # Case 1: join the native's occurrence; its slip wins.
    def link_to_native(observation, native)
      return if observation.occurrence_id == native.occurrence_id

      if observation.occurrence_id
        Occurrence.merge!(native.occurrence, observation.occurrence,
                          @import.user)
      else
        observation.update!(occurrence: native.occurrence)
      end
    end

    # Case 2. Set the column directly: `FieldSlip#project=` gates on
    # the current user's add-slip permission and silently keeps nil
    # here. The change fires `cascade_project_change`, which files the
    # occurrence's observations into the project.
    def reassign_slip(slip)
      return if slip.project_id == @project.id

      slip.update!(project_id: @project.id)
    end

    # Case 3: attach the slip named by a target-prefix code found in
    # the notes.
    def attach_from_notes(observation, code)
      FieldSlip::Attacher.attach(observation: observation, code: code,
                                 user: observation.user, join_in_use: true)
      keep_native_primary(observation.reload.occurrence)
    end

    # An in-use code joins an existing occurrence and `Attacher` makes
    # the joiner primary -- wrong when the joiner is a reflection and a
    # native member is present. Hand primary to the oldest native
    # member; an all-reflection occurrence keeps the reflection.
    def keep_native_primary(occurrence)
      return unless occurrence

      occurrence.reload
      return unless occurrence.primary_observation&.reflection?

      native = occurrence.observations.reject(&:reflection?).min_by(&:id)
      occurrence.update!(primary_observation: native) if native
    end

    # The first target-prefix code in the observation's notes.
    def notes_slip_code(observation)
      return nil if @prefix.blank?

      observation.notes.to_s[/\b#{Regexp.escape(@prefix)}-\d{1,6}\b/i]&.
        upcase
    end

    def ensure_member(observation)
      return if member?(observation)

      if admin_import? || !@project.violates_constraints?(observation)
        @project.add_observation(observation)
      else
        @import.add_constraint_violation_obs(observation.id)
      end
    end

    def member?(observation)
      @project.observations.exists?(id: observation.id)
    end

    def admin_import?
      @project.is_admin?(@import.user)
    end
  end
end
