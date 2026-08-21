# frozen_string_literal: true

# Enables "Add" button on ProjectsController#show and
# SpeciesListsController#show. Dispatches to either the
# ObservationsController#new, or FieldSlipsController#new,
# depending on whether field slip code is provided and
# whether it already exists.
class AddDispatchController < ApplicationController
  before_action :login_required

  def new
    # The project field is not required since not all Observation Lists are
    # associated with Projects. The field, if provided, overrides the project
    # of the field slip if it's different.
    # This is how the Project context gets passed if it is relevant.
    @project = find_project
    @field_slip_code = find_code(@project, params[:field_slip])
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

  def find_project
    project = Project.safe_find(params[:project])
    return project if project

    projects = find_species_list&.projects
    return nil unless projects

    projects.where.not(field_slip_prefix: nil).first
  end

  # Only a bare number gets the project prefix ("2345" ->
  # "PREFIX-2345"); anything else is taken as a complete code and
  # passed through unchanged. Prefixes can start with digits
  # ("2026-NAMATEST"), so a complete code is recognizable only by
  # matching the whole entry, not its first character.
  def find_code(project, code)
    code = code.to_s.strip
    return nil if code.blank?
    return code unless code.match?(/\A\d+\z/)
    return "#{project.field_slip_prefix}-#{code}" if
      project&.field_slip_prefix.present?

    flash_warning(:bad_dispatch_code.t(code:))
    nil
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
