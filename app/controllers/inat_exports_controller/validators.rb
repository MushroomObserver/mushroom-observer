# frozen_string_literal: true

module InatExportsController::Validators
  SITE = "https://www.inaturalist.org"

  private

  def params_valid?
    adequately_constrained? &&
      exportables?
  end

  def adequately_constrained?
    return true if params[:inat_username].present?

    flash_warning(:inat_export_no_username.l)
    false
  end

  def exportables?
    return true if params[:mo_ids].present?

    flash_warning(:inat_export_no_exportables.l)
    false
  end
end
