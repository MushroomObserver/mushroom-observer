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
      return :already_linked if @observation.occurrence_id

      existing = FieldSlip.find_by(code: @code)
      return join_or_refuse(existing) if existing&.occurrence
      return :closed_project if barred?(existing)

      slip = existing || FieldSlip.find_or_create_by_code(@code, @user)
      return :invalid unless slip

      link(slip)
      :attached
    end

    private

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
