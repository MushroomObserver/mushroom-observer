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
    "#{uri}?#{expected_obs_args(query_str).to_query}"
  end

  def already_imported_url
    base = requested_obs_url
    return nil unless base

    "#{base}&field:Mushroom%20Observer%20URL"
  end

  def unlicensed_obs_url
    requested_obs_url&.then { |u| "#{u}&licensed=false" }
  end

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

  def expected_obs_args(query_str)
    args = Rack::Utils.parse_query(query_str.to_s)
    args["iconic_taxa"] ||= "Fungi,Protozoa" unless args.key?("taxon_id")
    args["without_field"] = BASE_FILTER_PARAMS[:without_field]
    filter = LICENSED_FILTER.stringify_keys.transform_values(&:to_s)
    args.merge!(filter) if import_others?
    args
  end

  def translate_api_to_ui_params(query_str)
    args = Rack::Utils.parse_query(query_str.to_s)
    return args.to_query unless args["taxon_id"]&.include?(",")

    args.except("taxon_id").merge("iconic_taxa" => "Fungi,Protozoa").to_query
  end

  def normalize_inat_ui_url(url)
    uri, query_str = url.split("?", 2)
    "#{uri}?#{translate_api_to_ui_params(query_str.to_s)}"
  end

  def import_others?
    @model.import_others == "1"
  end
end
