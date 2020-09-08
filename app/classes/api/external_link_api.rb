# frozen_string_literal: true

class API
  # API for ExternalLink
  class ExternalLinkAPI < ModelAPI
    self.model = ExternalLink

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :external_site,
      { observation: [:location, :name, :user] },
      :user
    ]

    def query_params
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :creator),
        observations: parse_array(:observation, :observation),
        external_sites: parse_array(:external_site, :external_site),
        url: parse(:string, :url)
      }
    end

    def create_params
      {
        observation: parse(:observation, :observation),
        external_site: parse(:external_site, :external_site),
        url: parse(:string, :url),
        user: @user
      }
    end

    def update_params
      {
        url: parse(:string, :set_url, not_blank: true)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:observation))   unless params[:observation]
      raise(MissingParameter.new(:external_site)) unless params[:external_site]
      raise(MissingParameter.new(:url))           if params[:url].blank?
      return if params[:observation].can_edit?(@user)
      return if @user.external_sites.include?(params[:external_site])

      raise(ExternalLinkPermissionDenied.new)
    end
  end
end
