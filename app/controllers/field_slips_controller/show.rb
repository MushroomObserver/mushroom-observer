# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Show
  # GET /field_slips/1 or /field_slips/1.json or /qr/XYZ-123
  def show
    if params[:id].match?(/^\d+$/)
      set_field_slip
    else
      handle_by_code
    end
    redirect_to(new_field_slip_url(code: params[:id].upcase)) unless @field_slip
  end

  private

  def handle_by_code
    @field_slip = FieldSlip.find_by(code: params[:id].upcase)
    obs = @field_slip&.observation
    field_slip_redirect(obs.id) if obs
  end

  def field_slip_redirect(obs_id)
    redirect_to(observation_url(id: obs_id))
    # Didn't turn out to be a big win and it's confusing for
    # it to behave differently for recorders and regular users.
    # if foray_recorder?
    #   redirect_to(edit_field_slip_url(id: @field_slip.id))
    # else
    #   redirect_to(observation_url(id: obs_id))
    # end
  end

  def foray_recorder?
    project = @field_slip&.project
    return false unless project

    project.is_admin?(User.current) && project.happening?
  end
end
