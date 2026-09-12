# frozen_string_literal: true

# see sequences_controller.rb
#
# Sequences on a reflection are source-owned (mirrored from iNat by
# the resync), so a native sequence goes on the occurrence companion
# instead, like every other native contribution (#4214).
module SequencesController::ReflectionRouting
  private

  # Anyone may add a sequence to the specimen an observation
  # describes (labs sequence other people's collections), so a
  # reflection does not block the add -- it routes to the occurrence
  # companion. A GET redirects to the companion's form; a POST
  # re-targets in place so the submitted sequence is not lost.
  # Returns truthy when it handled the request.
  def route_reflection_to_companion!
    return false unless @observation.reflection?

    companion, notice = find_or_create_sequence_companion
    flash_notice(notice.t)
    if action_name == "create"
      @observation = companion
      false
    else
      redirect_to(new_sequence_path(observation_id: companion.id))
      true # redirect_to's return value is not contractually truthy
    end
  rescue ActiveRecord::RecordInvalid => e
    companion_creation_failed(e)
    true
  end

  def companion_creation_failed(error)
    flash_error(error.record.errors.full_messages.join("; "))
    redirect_to(permanent_observation_path(id: @observation.id))
  end

  # [companion, flash tag]. An actor with edit rights gets (or
  # reuses) a companion they hold, as in the Edit flow; anyone
  # else's sequence lands on the IMPORTER's companion -- the sequence
  # itself is owned by the adder either way, as on any native obs.
  def find_or_create_sequence_companion
    builder = Observation::Companion.new(@observation, companion_user)
    if (companion = builder.existing)
      [companion, :sequence_on_reflection_companion_existing]
    else
      [builder.create, :sequence_on_reflection_companion_created]
    end
  end

  def companion_user
    @observation.can_edit?(@user) ? @user : @observation.user
  end
end
