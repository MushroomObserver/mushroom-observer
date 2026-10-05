# frozen_string_literal: true

# An import a project admin starts for their project (#5416), rather
# than one a user starts for themselves.
#
# A site admin turns importing on for the project's iNaturalist row,
# which is what permits the arrangement; the project's admins are then
# the people who may act on it. What such an import covers is the
# project's configuration, not a choice made on the form, so the scope
# is rebuilt here on every submit and the form's url and project fields
# are not read.
module InatImportsController::ProjectScope
  private

  def scoped_project_site
    return @scoped_project_site if defined?(@scoped_project_site)

    @scoped_project_site = find_scoped_project_site
  end

  def project_admin_import? = scoped_project_site.present?

  def find_scoped_project_site
    id = params[:project_site].presence
    return nil if id.blank?

    site = ProjectExternalSite.importing.
           where(external_site: ExternalSite.inaturalist).
           includes(project: [:target_names, :target_locations, :location]).
           find_by(id: id)
    return nil unless site&.project&.is_admin?(@user)

    site
  end

  def project_search
    @project_search ||= Inat::ProjectSearch.new(scoped_project_site)
  end

  # The scope the project describes, in place of whatever the form
  # submitted for it. Runs before validation, so the rest of the
  # controller reads these params as it would any others.
  def apply_project_scope
    return unless project_admin_import?

    scope_params.each { |key, value| params[key] = value }
  end

  def scope_params
    {
      choose_method: "url", all: nil, inat_ids: nil,
      inat_url: project_search.url, original_inat_url: nil,
      inat_project_id: scoped_project_site.project_id.to_s,
      inat_project: scoped_project_site.project.title
    }
  end

  # Target names iNat does not know are left out of the search, so a
  # project none of whose names resolve would import every fungus in
  # its area and dates. Refused rather than imported.
  def project_targets_resolved?
    return true unless project_admin_import?
    return true if project_search.targets_resolved?

    flash_error(
      :inat_import_project_targets_unresolved.t(
        targets: project_search.unresolved_names.join(", ")
      )
    )
    false
  end
end
