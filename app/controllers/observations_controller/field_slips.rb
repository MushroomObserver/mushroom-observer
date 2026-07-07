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
  # :invalid when the code fails FieldSlip validation.
  def assign_field_slip(code)
    existed = FieldSlip.exists?(code: code)
    field_slip = FieldSlip.find_or_create_by_code(code, @user)
    return :invalid unless field_slip

    flash_notice(:field_slip_created.t(code: field_slip.code)) unless existed
    @observation.field_slip = field_slip
    @observation.save!
    field_slip.adopt_user_from(@observation)
    :assigned
  end
end
