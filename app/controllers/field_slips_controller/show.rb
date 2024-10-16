# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Show
  private

  # Use callbacks to share common setup or constraints between actions.
  # show
  def set_field_slip
    @field_slip = FieldSlip.find(params[:id])
  end

  # show
  def field_slip_redirect(obs_id)
    if foray_recorder?
      redirect_to(edit_field_slip_url(id: @field_slip.id))
    else
      redirect_to(observation_url(id: obs_id))
    end
  end

  # show
  def foray_recorder?
    project = @field_slip&.project
    return false unless project

    project.is_admin?(User.current) && project.happening?
  end
end
