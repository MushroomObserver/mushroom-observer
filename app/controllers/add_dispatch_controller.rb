# frozen_string_literal: true

# Enables "Add" button on ProjectsController#show and
# SpeciesListsController#show. Dispatches to either the
# ObservationsController#new, FieldSlipsController#new, or
# FieldSlipsController#new depending on whether field slip code is
# provided and whether it already exists.
class AddDispatchController < ApplicationController
  before_action :login_required
  before_action :pass_query_params

  def new
    # The project field is not required since not all Observation Lists are
    # associated with Projects. The field, if provided, overrides the project
    # of the field slip if it's different.
    # This is how the Project context gets passed if it is relevant.
    @project = Project.safe_find(params[:project])
    @field_slip_code = find_code(@project, params[:field_slip])&.strip
    url = if @field_slip_code
            "#{MO.http_domain}/qr/#{@field_slip_code}"
          else
            new_observation_path
          end
    new_params = dispatch_params
    url = "#{url}?#{new_params}" if new_params.present?

    redirect_to(url)
  end

  private

  def find_code(project, code)
    return nil if code.blank?
    return code unless project && code[0].match?(/\d/)

    "#{project.field_slip_prefix}-#{code}"
  end

  def dispatch_params
    {
      project: @project&.id,
      species_list: find_species_list&.id,
      name: params[:name],
      name_id: params[:name_id]
    }.compact_blank.to_query
  end

  def find_species_list
    return nil unless params[:object_type] == "SpeciesList"

    SpeciesList.safe_find(params[:object_id])
  end
end
