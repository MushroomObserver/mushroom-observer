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
  rescue RestClient::Exception, JSON::ParserError => e
    Rails.logger.warn("iNat estimate request failed: #{e.class}: #{e.message}")
    nil
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
    args = BASE_FILTER_PARAMS.merge(taxon_id: IMPORTABLE_TAXON_IDS_ARG,
                                    only_id: true)
    args[:id] = params[:inat_ids] if listing_ids?
    args
  end

  def import_estimate_query_args
    args = BASE_FILTER_PARAMS.merge(taxon_id: IMPORTABLE_TAXON_IDS_ARG,
                                    only_id: true)
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
end
