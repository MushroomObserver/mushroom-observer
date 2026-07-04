# frozen_string_literal: true

# Handling for listed iNat ids that were already imported to MO:
# warn about them and drop them from the id list before the import runs.
module InatImportsController::PreviousImports
  private

  # Were any listed iNat IDs previously imported?
  def warn_about_listed_previous_imports
    return if importing_all? || !listing_ids?

    previous_imports = previously_imported_links
    return if previous_imports.none?

    flash_warning(:inat_previous_import.t(count: previous_imports.count))
  end

  def previously_imported_links
    return ExternalLink.none if inat_id_list.blank?

    ExternalLink.import.where(target_type: "Observation",
                              external_site: inat_site,
                              external_id: inat_id_list.map(&:to_s))
  end

  def inat_site
    @inat_site ||= ExternalSite.inaturalist
  end

  def clean_inat_ids
    inat_ids = normalize_inat_ids(params[:inat_ids])
    previous_imports = previously_imported_links
    unless previous_imports.none?
      inat_ids = remove_previously_imported_ids(inat_ids, previous_imports)
    end
    # Write the cleaned list back so downstream readers in the same request
    # (importables_count via inat_id_list) count what will actually import.
    params[:inat_ids] = inat_ids
  end

  # Remove previously imported ids in case the iNat user deleted the
  # Mushroom_Observer_URL field.
  # NOTE: Also useful in manual testing when writes of iNat observations
  # are commented out temporarily. jdc 2026-01-15
  def remove_previously_imported_ids(inat_ids, previous_imports)
    previous_ids = previous_imports.pluck(:external_id)
    remaining_ids =
      inat_ids.split(",").map(&:strip).reject { |id| previous_ids.include?(id) }
    remaining_ids.join(",")
  end
end
