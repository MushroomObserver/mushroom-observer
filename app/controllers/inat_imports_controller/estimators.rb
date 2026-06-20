# frozen_string_literal: true

module InatImportsController::Estimators
  include Inat::Constants

  private

  def fetch_import_estimate
    response = RestClient.get(
      "#{API_BASE}/observations?#{import_estimate_query_args.to_query}",
      { accept: :json, open_timeout: 5, timeout: 10 }
    )
    JSON.parse(response.body)["total_results"]
  rescue RestClient::UnprocessableEntity => e
    flash_warning(:inat_unknown_param.t(error: inat_error_text(e)))
    false
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn("iNat estimate request failed: #{e.class}: #{e.message}")
    nil
  end

  def inat_error_text(exception)
    JSON.parse(exception.response.body)["error"]
  rescue JSON::ParserError
    exception.message
  end

  # Counts unlicensed observations for the own-observations case.
  # Total minus licensed gives the unlicensed count via two fast
  # only_id queries.
  def fetch_unlicensed_obs_count
    licensed = RestClient.get(
      "#{API_BASE}/observations?#{licensed_estimate_query_args.to_query}",
      { accept: :json, open_timeout: 5, timeout: 10 }
    )
    @estimate - JSON.parse(licensed.body)["total_results"]
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn(
      "iNat licensed estimate request failed: #{e.class}: #{e.message}"
    )
    nil
  end

  # Counts unlicensed observations that will be skipped for import-others.
  # @estimate is already licensed-only; total minus @estimate = unlicensed.
  def fetch_unlicensed_others_count
    total = RestClient.get(
      "#{API_BASE}/observations?#{total_others_estimate_query_args.to_query}",
      { accept: :json, open_timeout: 5, timeout: 10 }
    )
    JSON.parse(total.body)["total_results"] - @estimate
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn(
      "iNat unlicensed-others estimate request failed: #{e.class}: #{e.message}"
    )
    nil
  end

  # Total obs count for import-others without a license filter,
  # used to derive how many will be skipped.
  def total_others_estimate_query_args
    args = listing_url? ? url_query_args : {}
    args.merge!(BASE_FILTER_PARAMS, only_id: true)
    args[:taxon_id] ||= IMPORTABLE_TAXON_IDS_ARG
    args[:id] = params[:inat_ids] if listing_ids?
    args
  end

  def import_estimate_query_args
    args = listing_url? ? url_query_args : {}
    args.merge!(BASE_FILTER_PARAMS, only_id: true)
    args[:taxon_id] ||= IMPORTABLE_TAXON_IDS_ARG
    if import_others?
      args.merge!(LICENSED_FILTER)
    else
      args[:user_login] = params[:inat_username]&.strip
    end
    args[:id] = params[:inat_ids] if listing_ids?
    args
  end

  def licensed_estimate_query_args
    import_estimate_query_args.merge(LICENSED_FILTER)
  end

  # Strip MO-controlled params so estimates match actual import behavior.
  # Normal URL submissions are cleaned by normalize_inat_url_param! first;
  # this guards against raw query strings (no "://") that bypass it.
  def url_query_args
    strip = Inat::URLNormalizer::STRIP_PARAMS.map(&:to_sym)
    Rack::Utils.parse_query(params[:inat_url].to_s).symbolize_keys.except(*strip)
  end
end
