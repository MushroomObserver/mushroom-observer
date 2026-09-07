# frozen_string_literal: true

# Resolves the occurrence's editable primary observation for the edit
# form's "Edit Primary Observation" / "Create Editable Primary
# Observation" choice (target=primary, from the non-primary edit modal
# -- #5317). The clicked observation may be a read-only reflection or an
# editable non-primary member; this hands the editor the member it
# should change: the existing editable primary, the oldest editable
# sibling (promoted to primary), or a companion created from a
# reflection.
module ObservationsController::EditablePrimary
  private

  # target=primary routes here; otherwise a reflection opens its
  # companion. Returns the redirect when it stops the request.
  def redirect_for_companion_or_primary!
    return redirect_to_editable_primary! if params[:target] == "primary"

    redirect_to_companion!
  end

  def redirect_to_editable_primary!
    target, notice = resolve_editable_primary
    flash_notice(notice.t) if notice
    redirect_to(edit_observation_path(target.id))
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.record.errors.full_messages.join("; "))
    redirect_to(action: :show, id: @observation.id)
  end

  def resolve_editable_primary
    return [@observation, nil] unless @observation.occurrence_id

    # Fresh load: @observation's occurrence association is strict-loaded
    # (edit_includes), so its members/primary can't be read lazily.
    occ = Occurrence.find(@observation.occurrence_id)
    return [occ.primary_observation, nil] if editable_primary?(occ)

    promoted = oldest_editable_member(occ)
    return promote_to_primary(occ, promoted) if promoted

    [create_companion(occ), :edit_observation_companion_created]
  end

  def editable_primary?(occ)
    primary = occ.primary_observation
    primary && !primary.reflection? && primary.can_edit?(@user)
  end

  def oldest_editable_member(occ)
    occ.observations.reject(&:reflection?).
      select { |obs| obs.can_edit?(@user) }.min_by(&:id)
  end

  def promote_to_primary(occ, obs)
    occ.update!(primary_observation: obs)
    [obs, :edit_observation_promoted_primary]
  end

  # Source the reflection from the freshly-loaded occurrence, not the
  # strict-loaded @observation, so Companion's occurrence writes aren't
  # blocked by strict loading.
  def create_companion(occ)
    reflection = occ.observations.find(&:reflection?)
    Observation::Companion.new(reflection, @user).create
  end
end
