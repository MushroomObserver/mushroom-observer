# frozen_string_literal: true

class Inat::ConfirmURLBuilder
  include Inat::Constants

  def initialize(model)
    @model = model
  end

  def requested_obs_url
    query = requested_obs_query
    return nil unless query
    return normalize_inat_ui_url(query) if query.start_with?("http")

    "#{SITE}/observations?#{translate_api_to_ui_params(query)}"
  end

  def expected_obs_url
    base = requested_obs_url
    return nil unless base

    uri, query_str = base.split("?", 2)
    args = expected_obs_args(query_str)
    return nil unless args

    "#{uri}?#{args.to_query}"
  end

  def already_imported_url
    base = requested_obs_url
    return nil unless base

    "#{base}&field:Mushroom%20Observer%20URL"
  end

  def unlicensed_obs_url
    requested_obs_url&.then { |u| "#{u}&licensed=false" }
  end

  # Will the requested-obs URL always return the same results?
  def stable_result_set?
    return true if @model.inat_ids.present?
    return false unless (query = requested_obs_query)

    qs = query.start_with?("http") ? query.split("?", 2)[1].to_s : query
    Rack::Utils.parse_query(qs)["id"].present?
  end

  private

  def requested_obs_query
    m = @model
    return "id=#{m.inat_ids}" if m.inat_ids.present?
    return m.original_inat_url.strip if m.original_inat_url.present?
    return m.inat_url.strip if m.inat_url.present?

    "user_id=#{m.inat_username}" if m.inat_username.present?
  end

  # Returns nil when the user's own iconic_taxa rules out every
  # importable taxon (#4706) — signals the caller to show a plain count
  def expected_obs_args(query_str)
    args = Rack::Utils.parse_query(query_str.to_s)
    unless args.key?("taxon_id")
      iconic_taxa = importable_iconic_taxa(args["iconic_taxa"])
      return nil unless iconic_taxa

      args["iconic_taxa"] = iconic_taxa
    end
    unless skip_without_field?
      args["without_field"] = BASE_FILTER_PARAMS[:without_field]
    end
    filter = LICENSED_FILTER.stringify_keys.transform_values(&:to_s)
    args.merge!(filter) if import_others?
    args
  end

  # Narrows a user-supplied iconic_taxa list to the importable subset,
  # so the expected-obs link can't include taxa (e.g. Plantae) that
  # will never import. nil input defaults to the full importable set;
  # an input with no importable taxa at all returns nil.
  def importable_iconic_taxa(iconic_taxa)
    return IMPORTABLE_ICONIC_TAXA_ARG if iconic_taxa.blank?

    importable = iconic_taxa.split(",").map(&:strip) & IMPORTABLE_ICONIC_TAXA
    importable.join(",") if importable.any?
  end

  # Id lists always re-check obs already carrying the MO URL field, and
  # query modes re-check when the user opted in — so the expected-obs link
  # must not filter them out (#4565).
  def skip_without_field?
    @model.inat_ids.present? || @model.recheck_all == "1"
  end

  def translate_api_to_ui_params(query_str)
    args = Rack::Utils.parse_query(query_str.to_s)
    return args.to_query unless args["taxon_id"]&.include?(",")

    args.except("taxon_id").
      merge("iconic_taxa" => IMPORTABLE_ICONIC_TAXA_ARG).to_query
  end

  # map host and params to the iNat UI
  def normalize_inat_ui_url(url)
    _uri, query_str = url.split("?", 2)
    "#{SITE}/observations?#{translate_api_to_ui_params(query_str.to_s)}"
  end

  def import_others?
    @model.import_others == "1"
  end
end
