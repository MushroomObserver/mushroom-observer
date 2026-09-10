# frozen_string_literal: true

# see sequences_controller.rb
#
# Sequences on a reflection are source-owned (mirrored from iNat by
# the resync), so a native sequence goes on the occurrence companion
# instead, like every other native contribution (#4214).
module SequencesController::ReflectionRouting
  private

  # A GET redirects to the companion's form; a POST re-targets in
  # place so the submitted sequence is not lost. Returns truthy when
  # it handled the request.
  def route_reflection_to_companion!
    return false unless @observation.reflection?

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

  def companion_creation_failed(error)
    flash_error(error.record.errors.full_messages.join("; "))
    redirect_to(permanent_observation_path(id: @observation.id))
  end

  # [companion, flash tag]. The companion belongs to the reflection's
  # OWNER, whoever is adding the sequence -- anyone may add a sequence
  # (community data), but the native twin of an observer's record is
  # theirs; per-adder companions would splinter the occurrence. The
  # sequence itself is owned by the adder, as on any native obs.
  def find_or_create_sequence_companion
    builder = Observation::Companion.new(@observation, @observation.user)
    if (companion = builder.existing)
      [companion, :sequence_on_reflection_companion_existing]
    else
      [builder.create, :sequence_on_reflection_companion_created]
    end
  end
end
