# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Show
  # GET /field_slips/1 or /field_slips/1.json or /qr/XYZ-123
  def show
    resolve_field_slip_from_params
    params[:code] = params[:id].upcase
    # A lookup by code always redirects (see `handle_by_code`); only the
    # by-id path falls through to rendering the slip's own show page.
    return if performed?

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

  def render_show_or_keep_redirect
    respond_to do |format|
      format.html { render_show_view }
      format.json # auto-renders show.json.jbuilder
    end
  end

  def render_show_view
    render(Views::Controllers::FieldSlips::Show.new(
             field_slip: @field_slip, notice: flash[:notice]
           ))
  end

  # The question a scanned slip asks is "does this code already have
  # observations?", not "does a FieldSlip row exist?". With observations,
  # go to "the" observation — the occurrence's primary — so the flow reads
  # as *scan the slip, see the observation* without anyone needing to know
  # what an occurrence is. Without them, go to the observation form to
  # record one, whether or not a row happens to exist: slips are created
  # lazily, so an empty slip is indistinguishable from an unused code from
  # the scanner's side. An empty slip is reachable, not just legacy —
  # `Occurrence#destroy_if_incomplete!` keeps the occurrence alive when it
  # has a field slip, so detaching the last observation leaves one behind.
  # See #4932.
  def handle_by_code
    @field_slip = FieldSlip.show_includes.find_by(code: params[:id].upcase)
    obs = @field_slip&.observation
    return field_slip_redirect(obs.id) if obs

    redirect_to(new_observation_url(observation_form_params))
  end

  def field_slip_redirect(obs_id)
    redirect_to(observation_url(id: obs_id))
  end

  # Context carried from a scanned slip into the observation form.
  # `AddDispatchController` is what puts name/species_list/project on a
  # `/qr/` URL (the "Add" button on project and species-list pages); a
  # bare scan carries none of them.
  def observation_form_params
    { field_code: params[:id].upcase }.merge(
      params.permit(:name, :species_list, :project).to_h.compact_blank
    )
  end

  # Only allow a list of trusted parameters through.
  def show_params
    params.permit(:name, :name_id, :species_list, :code, :id, :project)
  end
end
