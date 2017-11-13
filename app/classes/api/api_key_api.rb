# API
class API
  # API for ApiKey
  class ApiKeyAPI < ModelAPI
    self.model = ApiKey

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :user
    ]

    def query_params
      {
        where:      sql_id_condition,
        created_at: parse_time_range(:created_at),
        updated_at: parse_time_range(:updated_at),
        notes_has:  parse_string(:notes)
      }
    end

    def create_params
      @for_user = parse_user(:for_user, default: @user)
      {
        notes:    parse_string(:app),
        user:     @for_user,
        verified: (@for_user == @user ? Time.now : nil)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:app) if params[:notes].blank?
    end

    def after_create(api_key)
      return if @for_user == @user
      VerifyAPIKeyEmail.build(@for_user, @user, api_key).deliver_now
    end

    def update_params
      {
        notes: parse_string(:set_app)
      }
    end

    def get
      raise NoMethodForAction.new("GET", :api_keys)
    end
  end
end
