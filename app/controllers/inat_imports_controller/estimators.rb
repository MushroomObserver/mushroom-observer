# frozen_string_literal: true

module InatImportsController::Estimators
  include Inat::Constants

  private

  def fetch_expected_count
    response = inat_get(import_estimate_query_args)
    JSON.parse(response.body)["total_results"]
  rescue RestClient::UnprocessableEntity => e
    flash_warning(:inat_unknown_param.t(error: inat_error_text(e)))
    false
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn(
      "iNat estimate request failed: #{e.class}: #{e.message}"
    )
    nil
  end

  def fetch_raw_requested_count
    inat_get_count(raw_requested_query_args)
  end

  def fetch_after_taxon_count
    inat_get_count(after_taxon_query_args)
  end

  def fetch_estimate_with_date_count
    args = import_estimate_query_args
    args[:d1] ||= EARLIEST_DATE_FILTER
    inat_get_count(args)
  end

  # Own-imports: count of obs in scope that carry no license.
  # Informational only — own obs are imported regardless of license.
  def fetch_unlicensed_obs_count
    inat_get_count(import_estimate_query_args.merge(licensed: false))
  end

  # Import-others: count of obs that are importable-taxa but not licensed.
  # These will be skipped entirely.
  def fetch_unlicensed_others_count
    args = import_estimate_query_args.except(:licensed).
           merge(licensed: false)
    inat_get_count(args)
  end

  def inat_error_text(exception)
    JSON.parse(exception.response.body)["error"]
  rescue JSON::ParserError
    exception.message
  end

  def inat_get(args)
    RestClient.get(
      "#{API_BASE}/observations?#{args.to_query}",
      { accept: :json, open_timeout: 5, timeout: 10 }
    )
  end

  def inat_get_count(args)
    response = inat_get(args)
    JSON.parse(response.body)["total_results"]
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn("iNat count request failed: #{e.class}: #{e.message}")
    nil
  end

  # All obs in user scope — no taxon, without_field, or license filter.
  def raw_requested_query_args
    args = listing_url? ? url_query_args : {}
    args[:only_id] = true
    args[:id] = params[:inat_ids] if listing_ids?
    args[:user_login] = params[:inat_username]&.strip unless import_others?
    args
  end

  # Obs in importable taxa — no without_field or license filter.
  def after_taxon_query_args
    args = listing_url? ? url_query_args : {}
    args[:only_id] = true
    args[:taxon_id] ||= IMPORTABLE_TAXON_IDS_ARG
    args[:id] = params[:inat_ids] if listing_ids?
    args[:user_login] = params[:inat_username]&.strip unless import_others?
    args
  end

  # Obs that will actually be imported: taxon + without_field
  # + licensed (for import-others) + user scope.
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

  # Strip MO-controlled params so estimates match actual import behavior.
  # Normal URL submissions are cleaned by normalize_inat_url_param! first;
  # this guards against raw query strings (no "://") that bypass it.
  def url_query_args
    strip = Inat::URLNormalizer::STRIP_PARAMS.map(&:to_sym)
    Rack::Utils.parse_query(params[:inat_url].to_s).
      symbolize_keys.except(*strip)
  end
end
