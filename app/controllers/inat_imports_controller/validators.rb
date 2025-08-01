# frozen_string_literal: true

module InatImportsController::Validators
  SITE = "https://www.inaturalist.org"

  private

  def params_valid?
    username_present? &&
      valid_inat_ids_param? &&
      imports_designated? &&
      list_within_size_limits? &&
      fresh_import? &&
      unmirrored? &&
      consented?
  end

  def username_present?
    return true if params[:inat_username].present?

    flash_warning(:inat_missing_username.l)
    false
  end

  def valid_inat_ids_param?
    return true unless contains_illegal_characters?

    flash_warning(:runtime_illegal_inat_id.l)
    false
  end

  def contains_illegal_characters?
    /[^\d ,]/.match?(params[:inat_ids])
  end

  def imports_designated?
    return true if importing_all? || params[:inat_ids].present?

    flash_warning(:inat_no_imports_designated.t)
    false
  end

  def importing_all?
    params[:all] == "1"
  end

  def list_within_size_limits?
    return true if importing_all? || params[:inat_ids].length <= 255

    flash_warning(:inat_too_many_ids_listed.t)
    false
  end

  # Are the listed iNat IDs fresh (i.e., not already imported)?
  def fresh_import?
    return true if importing_all?

    previous_imports = Observation.where(inat_id: inat_id_list)
    return true if previous_imports.none?

    previous_imports.each do |import|
      flash_warning(:inat_previous_import.t(inat_id: import.inat_id,
                                            mo_obs_id: import.id))
    end
    false
  end

  def inat_id_list
    params[:inat_ids].delete(" ").split(",").map(&:to_i)
  end

  def unmirrored?
    return true if importing_all?

    conditions = inat_id_list.map do |inat_id|
      Observation[:notes].matches("%Mirrored on iNaturalist as <a href=\"https://www.inaturalist.org/observations/#{inat_id}\">%")
    end
    previously_mirrored = Observation.where(conditions.inject(:or)).to_a
    return true if previously_mirrored.blank?

    previously_mirrored.each do |obs|
      flash_warning(:inat_previous_mirror.t(inat_id: mirrored_inat_id(obs),
                                            mo_obs_id: obs.id))
    end
    false
  end

  # When Pulk's `mirror`Python script copies an MO Obs to iNat,
  # it adds a link to the iNat obs in the MO Observation notes
  def mirrored_inat_id(obs)
    match = %r{#{SITE}/observations/(?'inat_id'\d+)}o.match(obs.notes.to_s)
    match[:inat_id]
  end

  def consented?
    return true if params[:consent] == "1"

    flash_warning(:inat_consent_required.t)
    false
  end
end
