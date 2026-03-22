# frozen_string_literal: true

module InatImportsController::Validators
  SITE = "https://www.inaturalist.org"

  # Maximum size of id list param, based on
  #  Puma max query string size (1024 * 10)
  #  MAX_COOKIE_SIZE
  #  - ~256 to allow for other stuff
  MAX_ID_LIST_SIZE =
    [1024 * 10, ActionDispatch::Cookies::MAX_COOKIE_SIZE].min - 256

  private

  def params_valid?
    import_adequately_constrained? &&
      imports_valid? &&
      consented?
  end

  # See InatImport.adequate_constraints?
  def import_adequately_constrained?
    return true if params[:inat_username].present?
    # Superimporters not importing own observations don't need a username;
    # the licensed + taxon filters in PageParser constrain the query.
    return true if superimporter_not_own?

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
    return true if importing_all? || # ignore list size if importing all
                   params[:inat_ids].length <= MAX_ID_LIST_SIZE

    flash_warning(:inat_too_many_ids_listed.t)
    false
  end

  def inat_id_list
    return [] unless listing_ids?

    params[:inat_ids].delete(" ").split(",").map(&:to_i)
  end

  # Block superimporter from importing **all** another user's iNat observations
  # when they have checked "Importing only my own". When the checkbox is
  # unchecked the query uses the licensed filter with no user_login, so
  # there is no "other user" to protect against.
  def not_importing_all_anothers?
    return true unless InatImport.super_importer?(@user) && importing_all?
    # Superimporter explicitly opted out of own-only: licensed filter applies.
    return true if superimporter_not_own?

    # user.inat_username can be nil if they've never done an iNat import or
    # if it got clobbered. We have no way to check if the iNat username they
    # entered is their actual iNat username. However, iNat authentication
    # requires them to know the password for that iNat username.
    return true if @user.inat_username.nil? ||
                   params[:inat_username] == @user.inat_username

    flash_warning(:inat_importing_all_anothers.t)
    false
  end

  def superimporter_not_own?
    InatImport.super_importer?(@user) && params[:own_observations] != "1"
  end

  def consented?
    return true if params[:consent] == "1"

    flash_warning(:inat_consent_required.t)
    false
  end
end
