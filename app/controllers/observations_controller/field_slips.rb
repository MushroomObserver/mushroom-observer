# frozen_string_literal: true

# Shared field-slip handling for the observation create and update actions.
#
# `update_field_slip` applies the `params[:field_code]` change to
# `@observation` and returns a status (:unchanged / :cleared / :assigned /
# :invalid). It deliberately does NOT flash errors or set `@any_errors` —
# create and update surface an invalid code differently: create warns and
# continues (the observation is already saved by the time this runs), while
# update flags `@any_errors` and re-renders the edit form so the user can
# fix the code.
module ObservationsController::FieldSlips
  private

  # The submitted field-slip code, normalized. Used both to apply the change
  # and to build the caller's invalid-code message.
  def field_code
    params[:field_code].to_s.strip.upcase
  end

  def update_field_slip
    return :unchanged unless params.key?(:field_code)

    code = field_code
    return :unchanged if code == @observation.field_slip&.code.to_s

    code.blank? ? clear_field_slip : assign_field_slip(code)
  end

  def clear_field_slip
    occ = @observation.occurrence
    return :cleared unless occ

    if occ.primary_observation_id == @observation.id
      @observation.send(:reassign_occurrence_primary, occ)
    end
    @observation.update!(occurrence: nil)
    if Occurrence.exists?(occ.id)
      occ.reload
      occ.destroy_if_incomplete!
    end
    :cleared
  end

  # Creates/reuses the field slip and links it to @observation via an
  # occurrence (Observation#field_slip= creates the occurrence). Returns
  # :invalid when the code fails FieldSlip validation, :too_many when the
  # slip's occurrence is already at capacity.
  def assign_field_slip(code)
    existed = FieldSlip.exists?(code: code)
    field_slip = FieldSlip.find_or_create_by_code(code, @user)
    return :invalid unless field_slip
    return :too_many if field_slip_occurrence_full?(field_slip)

    # Read before the assignment below, which is what creates the
    # occurrence when the slip doesn't have one yet.
    joined = field_slip.occurrence.present?
    flash_notice(:field_slip_created.t(code: field_slip.code)) unless existed
    @observation.field_slip = field_slip
    @observation.save!
    field_slip.adopt_user_from(@observation)
    sync_occurrence_after_attach(joined)
    :assigned
  end

  # `Occurrence#observation_count_within_limits` is `on: :update` for
  # Occurrence, but attaching updates the *Observation*, so the cap never
  # fires on this path and has to be checked here.
  def field_slip_occurrence_full?(field_slip)
    occ = field_slip.occurrence
    return false unless occ

    occ.observations.count >= Occurrence::MAX_OBSERVATIONS
  end

  # The occurrence-edit and field-slip forms do this bookkeeping every
  # time they attach an observation; this path did none of it.
  #
  # Logging fires only when the observation joined an occurrence that
  # already existed. For a freshly created slip the occurrence holds just
  # this observation, whose own creation entry already says everything
  # there is to say, and a second entry would double every QR-created
  # observation in the activity feed.
  def sync_occurrence_after_attach(joined)
    occ = @observation.occurrence
    return unless occ

    Occurrence.log_field_slip_added([@observation], @user) if joined
    occ.reload
    occ.recompute_has_specimen!
    occ.recalculate_consensus!(@user)
  end
end
