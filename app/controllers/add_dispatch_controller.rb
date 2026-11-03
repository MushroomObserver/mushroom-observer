# frozen_string_literal: true

# Enables "Add" button on ProjectsController#show and
# SpeciesListsController#show. A field slip code that already has an
# observation adds that observation to the page's project and list and
# shows it; otherwise dispatches to ObservationsController#new or the
# field slip's /qr/ page.
class AddDispatchController < ApplicationController
  include OccurrenceProjectResolvable

  before_action :login_required

  def new
    # The project field is not required since not all Observation Lists are
    # associated with Projects. The field, if provided, overrides the project
    # of the field slip if it's different.
    # This is how the Project context gets passed if it is relevant.
    @project = find_project
    @field_slip_code = find_code(@project, params[:field_slip])
    slip = used_field_slip
    return add_existing_observation(slip) if slip

    new_params = dispatch_params

    if @field_slip_code
      url = "#{MO.http_domain}/qr/#{@field_slip_code}"
      url = "#{url}?#{new_params}" if new_params.present?
      redirect_to(url, allow_other_host: true)
    else
      url = new_observation_path
      url = "#{url}?#{new_params}" if new_params.present?
      redirect_to(url)
    end
  end

  private

  def used_field_slip
    return nil unless @field_slip_code

    slip = FieldSlip.find_by(code: @field_slip_code.upcase)
    slip&.observation ? slip : nil
  end

  # Adds every observation of the slip's occurrence, so its members stay
  # in the same collections. The occurrence applies the project rules:
  # members only, and only admins past a constraint violation. A
  # collection already holding them all is left out, so it gets "already
  # in" rather than a refusal or a constraint warning.
  def add_existing_observation(slip)
    present, projects, lists = sort_collections(slip.occurrence)
    result = slip.occurrence.add_all_to_collections(
      projects:, species_lists: lists, user: @user, site_admin: in_admin_mode?
    )
    obs = slip.observation
    flash_already_in(obs, present)
    flash_additions(obs, (projects - result[:refused]) + lists)
    flash_add_all_result(result)
    redirect_to(permanent_observation_path(obs.id))
  end

  # [collections already holding the occurrence, projects to add it to,
  # lists to add it to]
  def sort_collections(occurrence)
    present, projects = split_present([@project].compact, occurrence)
    present_lists, lists = split_present([find_species_list].compact,
                                         occurrence)
    [present + present_lists, projects,
     lists.select { |list| permission!(list) }]
  end

  # [collections already holding the whole occurrence, the rest]
  def split_present(collections, occurrence)
    collections.partition do |collection|
      (occurrence.observation_ids - collection.observation_ids).empty?
    end
  end

  def flash_already_in(obs, collections)
    collections.each do |collection|
      flash_notice(:add_dispatch_already_in.t(name: collection_name(collection),
                                              id: obs.id))
    end
  end

  def flash_additions(obs, collections)
    collections.each do |collection|
      tag = if collection.is_a?(Project)
              :runtime_project_add_observation_success
            else
              :runtime_species_list_add_observation_success
            end
      flash_notice(tag.t(name: collection_name(collection), id: obs.id))
    end
  end

  def collection_name(collection)
    return collection.title if collection.is_a?(Project)

    collection.unique_format_name
  end

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
