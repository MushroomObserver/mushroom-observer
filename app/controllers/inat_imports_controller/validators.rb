# frozen_string_literal: true

module InatImportsController::Validators
  SITE = "https://www.inaturalist.org"

  private

  def params_valid?
    import_adequately_constrained? &&
      imports_valid? &&
      consented?
  end

  # See InatImport.adequate_constraints?
  def import_adequately_constrained?
    return true if params[:inat_username].present?

    flash_warning(:inat_missing_username.l)
    false
  end

  def imports_valid?
    imports_unambiguously_designated? &&
      valid_inat_ids_param? &&
      list_within_size_limits? &&
      not_importing_all_anothers?
  end

  def imports_unambiguously_designated?
    if (importing_all? && !listing_ids?) || (listing_ids? && !importing_all?)
      return true
    end

    flash_warning(:inat_list_xor_all.l)
    false
  end

  def importing_all?
    params[:all] == "1"
  end

  def listing_ids?
    params[:inat_ids].present?
  end

  def valid_inat_ids_param?
    return true unless contains_illegal_characters?

    flash_warning(:runtime_illegal_inat_id.l)
    false
  end

  def contains_illegal_characters?
    /[^\d ,]/.match?(params[:inat_ids])
  end

  def list_within_size_limits?
    # Limit based on Puma max query string (10,240 chars)
    # Subtract ~256 for other params = 9,984 chars available
    # This allows ~900 iNat IDs (9 digits + separator = 10 chars each)
    return true if importing_all? || # ignore list size if importing all
                   params[:inat_ids].length <= 9984

    flash_warning(:inat_too_many_ids_listed.t)
    false
  end

  def inat_id_list
    params[:inat_ids].delete(" ").split(",").map(&:to_i)
  end

  # Block importing **all** of another user's iNat observations
  # Seems so hard to reverse if done accidentally that we should prevent it,
  # at least for now.
  def not_importing_all_anothers?
    unless importing_all? &&
           (params[:inat_username] != @user.inat_username)
      return true
    end

    flash_warning(:inat_importing_all_anothers.t)
    false
  end

  def consented?
    return true if params[:consent] == "1"

    flash_warning(:inat_consent_required.t)
    false
  end
end
