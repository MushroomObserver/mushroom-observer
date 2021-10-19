# frozen_string_literal: true

class API2
  # API for ApiKey
  class ApiKeyAPI < ModelAPI
    self.model = ApiKey

    self.high_detail_page_length = 1000
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    def create_params
      @for_user = parse(:user, :for_user, help: :api_key_user) || @user
      {
        notes: parse(:string, :app, help: 1),
        user: @for_user,
        verified: (valid_password? ? Time.zone.now : nil)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:app)) if params[:notes].blank?
    end

    def after_create(api_key)
      return if api_key.verified

      VerifyAPIKeyEmail.build(@for_user, @user, api_key).deliver_now
    end

    def get
      raise(NoMethodForAction.new("GET", :api_keys))
    end

    def patch
      raise(NoMethodForAction.new("PATCH", :api_keys))
    end

    def delete
      raise(NoMethodForAction.new("DELETE", :api_keys))
    end

    private

    def valid_password?
      password = parse(:string, :password, help: :api_key_password)
      return @for_user == @user if password.blank?
      if User.authenticate(login: @for_user.login, password: password) == @for_user
        return true
      end

      raise(PasswordIncorrect.new)
    end
  end
end
