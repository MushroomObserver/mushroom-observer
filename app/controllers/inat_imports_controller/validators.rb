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
    # Superimporters importing by specific ID list or URL don't need a
    # username; the filter constraints are sufficient.
    return true if superimporter_not_own? && (listing_ids? || listing_url?)

    flash_warning(:inat_missing_username.l)
    false
  end

  def imports_valid?
    imports_unambiguously_designated? &&
      valid_inat_ids_param? &&
      valid_inat_url_param? &&
      list_within_size_limits? &&
      not_importing_all_anothers?
  end

  def imports_unambiguously_designated?
    modes = [importing_all?, listing_ids?, listing_url?].count(true)
    return true if modes == 1

    flash_warning(:inat_list_xor_all.l)
    false
  end

  def importing_all?
    params[:all] == "1"
  end

  def listing_ids?
    params[:inat_ids].present?
  end

  def listing_url?
    params[:inat_url].present?
  end

  def valid_inat_ids_param?
    return true unless contains_illegal_characters? ||
                       contains_malformed_id_tokens? ||
                       (listing_ids? && inat_id_list.none?)

    flash_warning(:runtime_illegal_inat_id.l)
    false
  end

  def contains_illegal_characters?
    /[^\w\s,]/.match?(params[:inat_ids])
  end

  def contains_malformed_id_tokens?
    return false unless params[:inat_ids]

    params[:inat_ids].split(/[\s,]+/).any? do |token|
      token.match?(/\d/) && token.match?(/[a-zA-Z]/)
    end
  end

  def valid_inat_url_param?
    return true unless listing_url?
    # On the confirm round-trip the URL is already a normalized query string;
    # it was validated on the first submit so accept it as-is.
    return true if confirmed_url_mode?

    keep = url_taxon_ids_importable?
    normalizer = url_normalizer(params[:inat_url], keep_taxon_id: keep)
    normalized = normalizer.normalize
    return true if normalized.present?

    # When all URL params were stripped, warn about what was ignored.
    # Normally these warnings fire in normalize_inat_url_param!, which is
    # never reached when validation fails.
    if normalized == ""
      warn_about_ignored_url_params(normalizer)
      warn_about_non_importable_taxon unless keep
    end
    msg = if normalized.nil?
            :inat_invalid_url.l
          else
            :inat_url_no_valid_filter_params.l
          end
    flash_warning(msg)
    false
  end

  def confirmed_url_mode?
    params[:confirmed] == "1" && params[:inat_url].exclude?("://")
  end

  def list_within_size_limits?
    return true if importing_all? || listing_url? ||
                   params[:inat_ids].length <= MAX_ID_LIST_SIZE

    flash_warning(:inat_too_many_ids_listed.t)
    false
  end

  def inat_id_list
    return [] unless listing_ids?

    params[:inat_ids].split(/[\s,]+/).
      grep(/\A\d+\z/).
      map(&:to_i)
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
    InatImport.super_importer?(@user) && params[:import_others] == "1"
  end

  def consented?
    return true if params[:consent] == "1"

    flash_warning(:inat_consent_required.t)
    false
  end
end
