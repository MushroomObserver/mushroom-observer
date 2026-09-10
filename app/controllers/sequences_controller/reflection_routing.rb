# frozen_string_literal: true

# see sequences_controller.rb
#
# Sequences on a reflection are source-owned (mirrored from iNat by
# the resync), so a native sequence goes on the occurrence companion
# instead, like every other native contribution (#4214).
module SequencesController::ReflectionRouting
  private

  # Attaching a sequence to a reflection is an edit-like act on the
  # occurrence -- it materializes or reuses the companion -- so it
  # takes the same permission as Edit (`can_edit?`: the owner, or a
  # project admin the owner trusts). The companion belongs to the
  # ACTOR, as in the Edit flow. A GET redirects to the companion's
  # form; a POST re-targets in place so the submitted sequence is not
  # lost. Returns truthy when it handled the request.
  def route_reflection_to_companion!
    return false unless @observation.reflection?
    return reject_reflection_sequence! unless @observation.can_edit?(@user)

    companion, notice = find_or_create_sequence_companion
    flash_notice(notice.t)
    if action_name == "create"
      @observation = companion
      false
    else
      redirect_to(new_sequence_path(observation_id: companion.id))
    end
  rescue ActiveRecord::RecordInvalid => e
    companion_creation_failed(e)
  end

  def reject_reflection_sequence!
    flash_error(:sequence_on_reflection_not_editable.t)
    redirect_to(permanent_observation_path(id: @observation.id))
  end

  def companion_creation_failed(error)
    flash_error(error.record.errors.full_messages.join("; "))
    redirect_to(permanent_observation_path(id: @observation.id))
  end

  # [companion, flash tag]
  def find_or_create_sequence_companion
    builder = Observation::Companion.new(@observation, @user)
    if (companion = builder.existing)
      [companion, :sequence_on_reflection_companion_existing]
    else
      [builder.create, :sequence_on_reflection_companion_created]
    end
  end
end
