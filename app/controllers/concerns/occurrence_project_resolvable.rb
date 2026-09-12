# frozen_string_literal: true

# Reporting the outcome of an "add all" project resolution, shared by the
# two controllers that offer it — `OccurrencesController#create` previews
# the gap before the occurrence exists, `Occurrences::ProjectsController`
# resolves it afterwards.
module OccurrenceProjectResolvable
  extend ActiveSupport::Concern

  private

  # `Occurrence#add_all_to_collections` returns `{ refused:, forced: }`.
  # Both need saying. A refused project was left out, so the gap it
  # represents is still there. A forced one went in despite an
  # observation violating its constraints, which an admin is entitled to
  # do but should not discover by accident. See #4932.
  def flash_add_all_result(result)
    flash_resolution_projects(:occurrence_resolve_projects_refused,
                              result[:refused])
    flash_resolution_projects(:occurrence_resolve_projects_forced,
                              result[:forced])
  end

  def flash_resolution_projects(tag, projects)
    return if projects.empty?

    flash_warning(tag.t(projects: projects.map(&:title).join(", ")))
  end
end
