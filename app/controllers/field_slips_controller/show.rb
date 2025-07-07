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
    params[:code] = params[:id].upcase
    redirect_to(new_field_slip_url(show_params)) unless @field_slip
  end

  private

  def handle_by_code
    @field_slip = FieldSlip.find_by(code: params[:id].upcase)
    obs = @field_slip&.observation
    field_slip_redirect(obs.id) if obs
  end

  def field_slip_redirect(obs_id)
    redirect_to(observation_url(id: obs_id))
  end

  # Only allow a list of trusted parameters through.
  def show_params
    params.permit(:name, :name_id, :species_list, :code, :id, :project)
  end
end
