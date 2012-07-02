# encoding: utf-8

class API
  class ApiKeyAPI < ModelAPI
    self.model = ApiKey

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :user,
    ]

    def query_params
      {
        :created   => parse_time_ranges(:created),
        :verified  => parse_time_ranges(:verified),
        :last_used => parse_time_ranges(:last_used),
        :num_uses  => parse_integer_ranges(:num_uses),
        :users     => parse_users(:user),
        :notes     => parse_strings(:app),
      }
    end

    def create_params
      @for_user = parse_user(:for_user, :default => @user)
      {
        :notes    => parse_string(:app),
        :user     => @for_user,
        :verified => (@for_user == @user ? Time.now : nil),
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:app) if params[:notes].blank?
    end

    def after_create(api_key)
      if @for_user != @user
        AccountMailer.deliver_verify_api_key(@for_user, @user, api_key)
      end
    end

    def update_params
      {
        :notes => parse_string(:set_notes),
      }
    end
  end
end
