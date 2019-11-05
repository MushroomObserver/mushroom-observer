class API
  # API for User
  class UserAPI < ModelAPI
    self.model = User

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :api_keys,
      :location,
      :image
    ]

    def query_params
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at)
      }
    end

    def create_params
      @create_key = parse(:string, :create_key, help: 1)
      {
        login: parse(:string, :login, limit: 80),
        name: parse(:string, :name, limit: 80, default: ""),
        email: parse(:email, :email, limit: 80),
        password: parse(:string, :password, limit: 80),
        locale: parse(:lang, :locale),
        notes: parse(:string, :notes, default: ""),
        mailing_address: parse(:string, :mailing_address, default: ""),
        license: parse(:license, :license, default: License.preferred),
        location: parse(:location, :location),
        image: parse(:image, :image),
        verified: nil,
        admin: false,
        layout_count: 15
      }
    end

    def update_params
      {
        # These all seem too dangerous to allow for now.
        # login:    parse(:string, :set_login, limit: 80),
        # name:     parse(:string, :set_name, limit: 80, default: ""),
        # email:    parse(:email, :set_email, limit: 80),
        # password: parse(:string, :set_password, limit: 80),
        locale: parse(:lang, :set_locale, not_blank: true),
        notes: parse(:string, :set_notes, default: ""),
        mailing_address: parse(:string, :set_mailing_address, default: ""),
        license: parse(:license, :set_license, not_blank: true),
        location: parse(:location, :set_location),
        image: parse(:image, :set_image, must_be_owner: true)
      }
    end

    def validate_create_params!(params)
      login = params[:login]
      raise MissingParameter.new(:login)    unless params[:login]
      raise MissingParameter.new(:name)     unless params[:name]
      raise MissingParameter.new(:email)    unless params[:email]
      raise MissingParameter.new(:password) unless params[:password]
      raise UserAlreadyExists.new(login)    if User.find_by_login(login)

      params[:password_confirmation] = params[:password]
    end

    def after_create(user)
      return unless @create_key

      key = ApiKey.new(notes: @create_key, user: user)
      key.provide_defaults
      key.verified = nil
      key.save
      user.reload
    end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end
  end
end
