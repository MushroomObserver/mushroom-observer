# frozen_string_literal: true

class FieldSlip
  # Attaches a slip-less observation to the field slip a code names --
  # the silent counterpart of the observation form's field_code path
  # (ObservationsController::FieldSlips#assign_field_slip), for
  # photo-first observations where the code arrives as pixels in an
  # uploaded photo rather than as a scan or a typed field.
  #
  # Deliberately narrower than the interactive path, because nobody is
  # watching: it acts only when the observation has no occurrence and
  # the code's slip is unused, so it can never move an observation,
  # join one to somebody else's collection, or override a choice a
  # person made on a form.
  #
  # `join_in_use: true` widens that for a human-confirmed call site
  # (the review form's ticked code): an in-use slip's occurrence is
  # joined instead of refused, the same act as editing the code onto
  # the observation, and the newly reviewed observation becomes the
  # occurrence's primary.
  class Attacher
    def self.attach(observation:, code:, user:, join_in_use: false)
      new(observation: observation, code: code, user: user,
          join_in_use: join_in_use).attach
    end

    def initialize(observation:, code:, user:, join_in_use: false)
      @observation = observation
      @code = code.to_s.strip.upcase
      @user = user
      @join_in_use = join_in_use
    end

    # Returns what happened, for the caller's log line.
    def attach
      existing = FieldSlip.find_by(code: @code)
      return attach_with_occurrence(existing) if @observation.occurrence_id
      return join_or_refuse(existing) if existing&.occurrence
      return :closed_project if barred?(existing)

      slip = existing || FieldSlip.find_or_create_by_code(@code, @user)
      return :invalid unless slip

      link(slip)
      :attached
    end

    private

    # The observation already belongs to an occurrence. Three shapes:
    # the code names a slip on a different occurrence (merge), the
    # occurrence carries no field slip yet -- a reflection's
    # Edit-companion (adopt the read slip onto that shared occurrence),
    # or the occurrence already holds a slip and the read code adds
    # nothing (leave it).
    def attach_with_occurrence(existing)
      return merge_or_refuse(existing) if existing&.occurrence
      unless @join_in_use && @observation.occurrence.field_slip.nil?
        return :already_linked
      end

      adopt_into_occurrence(existing)
    end

    # Set the read slip on the occurrence the observation already sits
    # in, rather than the fresh occurrence `link` would build -- which
    # would strand the occurrence's other members (the reflection)
    # outside the slip.
    def adopt_into_occurrence(existing)
      return :closed_project if barred?(existing)

      slip = existing || FieldSlip.find_or_create_by_code(@code, @user)
      return :invalid unless slip

      @observation.occurrence.update!(field_slip: slip)
      slip.adopt_user_from(@observation)
      refresh_occurrence
      apply_project(slip)
      :attached
    end

    # An existing slip already in a project the user can neither join
    # nor is a member of: attaching would put the observation in that
    # project against invariant 4 (see #4932). A NEW code never lands
    # here -- `FieldSlip#update_project` declines to set a project the
    # user can't add to, so the slip just comes out project-less.
    def barred?(slip)
      project = slip&.project
      project && !project.member?(@user) && !project.can_join?(@user)
    end

    def join_or_refuse(slip)
      return :in_use unless @join_in_use
      return :occurrence_full if occurrence_full?(slip)
      return :closed_project if barred?(slip)

      link(slip)
      # The reviewed observation carries the slip's freshly applied
      # data, so it becomes the record the slip's /qr/ page shows.
      slip.occurrence.update!(primary_observation_id: @observation.id)
      Occurrence.log_field_slip_added([@observation], @user)
      :joined
    end

    def occurrence_full?(slip)
      slip.occurrence.observations.count >= Occurrence::MAX_OBSERVATIONS
    end

    # The observation already belongs to an occurrence, and the slip's
    # code names a slip on a different one -- both hold observations of
    # the same collection, so merge them (only on the human-confirmed
    # review path; the background job leaves it alone). Merge INTO the
    # slip's occurrence so its field slip and primary survive (see
    # Occurrence.merge!, which keeps the keeper's).
    def merge_or_refuse(slip)
      occ = @observation.occurrence
      return :already_linked unless @join_in_use && slip&.occurrence
      return :already_linked if slip.occurrence.id == occ.id

      refusal = merge_refusal(slip, occ)
      return refusal if refusal

      Occurrence.merge!(slip.occurrence, occ, @user)
      ensure_native_primary(slip.occurrence)
      @observation.reload
      apply_project(slip)
      :merged
    end

    # The reason this merge can't happen, or nil.
    def merge_refusal(slip, occ)
      if occ.field_slip && occ.field_slip_id != slip.id
        :occurrence_conflict
      elsif merge_overflows?(slip, occ)
        :occurrence_full
      elsif barred?(slip)
        :closed_project
      end
    end

    def merge_overflows?(slip, occ)
      combined = (slip.occurrence.observation_ids | occ.observation_ids)
      combined.size > Occurrence::MAX_OBSERVATIONS
    end

    # A reflection may not be an occurrence's primary; if the merge
    # left one there, repoint to the oldest native member.
    def ensure_native_primary(occurrence)
      occurrence.reload
      primary = occurrence.primary_observation
      return unless primary&.reflection?

      native = occurrence.observations.reject(&:reflection?).min_by(&:id)
      occurrence.update!(primary_observation: native) if native
    end

    def link(slip)
      @observation.field_slip = slip
      @observation.save!
      slip.adopt_user_from(@observation)
      refresh_occurrence
      apply_project(slip)
    end

    # The bookkeeping every attach path owes the occurrence. No
    # activity-log entry: the occurrence is freshly created for this
    # one observation, whose own creation entry already says it all.
    def refresh_occurrence
      occ = @observation.occurrence
      occ.reload
      occ.recompute_has_specimen!
      occ.recalculate_consensus!(@user)
    end

    # Using a slip for an open-membership project enrolls the user, the
    # way scanning one always has -- that is what a printed prefix
    # means. The observation then joins the project too, unless it
    # violates the project's constraints, in which case the slip goes
    # spare along with its observation (#4932 invariant 2) -- the
    # review's reconcile restores both, via the printed prefix, once
    # the real data lands.
    def apply_project(slip)
      project = slip.project
      return unless project

      project.join(@user)
      return unless project.member?(@user)

      if project.violates_constraints?(@observation)
        slip.update!(project: nil)
        return
      end

      project.add_observation(@observation)
    end
  end
end
