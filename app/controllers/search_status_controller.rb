# frozen_string_literal: true

# Dispatches to either the ObservationsController#new
# or FieldSlipsController#new depending on whether
# field slip code is provided.
class SearchStatusController < ApplicationController
  before_action :login_required
  before_action :pass_query_params

  def add
    @project = Project.find(params[:project])
    @species_list = find_species_list
    @field_slip_code = find_code(@project, params[:field_slip])
    # Need to pass @project, @species_list, params[:name], params[:name_id]
    if @field_slip_code
      redirect_to("#{MO.http_domain}/qr/#{@field_slip_code.strip}",
                  code: @field_slip_code)
    else
      redirect_to(new_observation_path)
    end
  end

  private

  def find_species_list
    return nil unless params[:object_type] == "SpeciesList"

    SpeciesList.find(params[:object_id])
  end

  def find_code(project, code)
    return nil unless code.present? && project
    return "#{project.field_slip_prefix}-#{code}" if code[0].match?(/\d/)

    code
  end
end
