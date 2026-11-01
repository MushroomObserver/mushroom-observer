# frozen_string_literal: true

class API2
  # API for ExternalLink
  class ExternalLinkAPI < ModelAPI
    def model
      ExternalLink
    end

    def high_detail_includes
      [
        :external_site,
        :user
      ]
    end

    def query_params
      {
        id_in_set: parse_array(:external_link, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :creator),
        observations: parse_array(:observation, :observation),
        external_sites: parse_array(:external_site, :external_site)
      }
    end

    # `url:` stays the public param name for backward compatibility;
    # internally it becomes `external_id:` -- the model resolves a
    # pasted url to the site's bare id, or rejects it, before save.
    # There's no url column left to store it in verbatim.
    def create_params
      {
        observation: parse(:observation, :observation),
        external_site: parse(:external_site, :external_site),
        external_id: parse(:string, :url),
        user: @user
      }
    end

    def update_params
      {
        external_id: parse(:string, :set_url, not_blank: true)
      }
    end

    # Same url-shape contract as create -- see check_required_create_params!.
    def validate_update_params!(params)
      return if params[:external_id].to_s.include?("://")

      raise(BadParameterValue.new(params[:external_id], "url"))
    end

    def validate_create_params!(params)
      check_required_create_params!(params)
      unless params[:observation].can_edit?(@user) ||
             @user.external_sites.include?(params[:external_site])
        raise(ExternalLinkPermissionDenied.new)
      end
      # The model now allows multiple links per (obs, site), but a user adding
      # an exact duplicate is an error, not a new correspondence (#4565).
      return unless duplicate?(params)

      raise(ExternalLinkAlreadyExists.new(params[:external_id]))
    end

    def check_required_create_params!(params)
      raise(MissingParameter.new(:observation))   unless params[:observation]
      raise(MissingParameter.new(:external_site)) unless params[:external_site]
      raise(MissingParameter.new(:url)) if params[:external_id].blank?
      # The public param is named `url`, so the API's contract requires a
      # url -- unlike the web form's smart field, which also accepts a
      # bare id. A non-url string doesn't reach the model's url-vs-id
      # branch, so it would otherwise be stored unvalidated.
      return if params[:external_id].to_s.include?("://")

      raise(BadParameterValue.new(params[:external_id], "url"))
    end

    # Compare against the model-resolved external_id (a pasted url is
    # resolved to the site's bare id before comparing), so an
    # equivalent-but-differently-formatted paste can't slip past as "new".
    def duplicate?(params)
      candidate = ExternalLink.new(observation: params[:observation],
                                   external_site: params[:external_site],
                                   external_id: params[:external_id])
      candidate.valid? # runs the before_validation resolution
      params[:observation].external_links.exists?(
        external_site: params[:external_site],
        external_id: candidate.external_id
      )
    end
  end
end
