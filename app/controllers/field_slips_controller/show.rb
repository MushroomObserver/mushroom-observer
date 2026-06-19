# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Show
  # GET /field_slips/1 or /field_slips/1.json or /qr/XYZ-123
  def show
    resolve_field_slip_from_params
    params[:code] = params[:id].upcase
    if @field_slip
      render_show_or_keep_redirect
    else
      redirect_to(new_field_slip_url(show_params))
    end
  end

  private

  def resolve_field_slip_from_params
    if params[:id].match?(/^\d+$/)
      @field_slip = FieldSlip.show_includes.find_by(id: params[:id])
    else
      handle_by_code
    end
  end

  # `handle_by_code` may have already redirected to an observation
  # when the code resolved to a single obs; bail before re-rendering.
  def render_show_or_keep_redirect
    return if performed?

    respond_to do |format|
      format.html { render_show_phlex }
      format.json # auto-renders show.json.jbuilder
    end
  end

  def render_show_phlex
    render(Views::Controllers::FieldSlips::Show.new(
             field_slip: @field_slip, notice: flash[:notice]
           ))
  end

  def handle_by_code
    @field_slip = FieldSlip.show_includes.find_by(code: params[:id].upcase)
    return unless @field_slip&.observations&.any?

    obs = @field_slip.observation
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
