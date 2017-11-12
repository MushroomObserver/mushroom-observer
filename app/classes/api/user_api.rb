# API
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
        created_at: parse_time_range(:created_at),
        updated_at: parse_time_range(:updated_at)
        # :login        => parse_strings(:login),
        # :name         => parse_strings(:name),
        # :locations    => parse_strings(:location),
        # :images       => parse_images(:image),
        # :has_location => parse_boolean(:has_location),
        # :has_image    => parse_boolean(:has_image),
        # :has_notes    => parse_boolean(:has_notes),
        # :notes_has    => parse_strings(:notes_has),
      }
    end

    def create_params
      @create_key = parse_string(:create_key)
      {
        login:           parse_string(:login, limit: 80),
        name:            parse_string(:name, limit: 80, default: ""),
        email:           parse_email(:email, limit: 80),
        password:        parse_string(:password, limit: 80),
        locale:          parse_lang(:locale),
        notes:           parse_string(:notes, default: ""),
        mailing_address: parse_string(:mailing_address, default: ""),
        license:         parse_license(:license, default: License.preferred),
        location:        parse_location(:location),
        image:           parse_image(:image),
        verified:        nil,
        admin:           false,
        layout_count:    15
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

    def update_params
      {
        login:           parse_string(:login, limit: 80),
        name:            parse_string(:name, limit: 80, default: ""),
        email:           parse_email(:email, limit: 80),
        password:        parse_string(:password, limit: 80),
        locale:          parse_lang(:locale),
        notes:           parse_string(:notes, default: ""),
        mailing_address: parse_string(:mailing_address, default: ""),
        license:         parse_license(:license, default: License.preferred),
        location:        parse_location(:location),
        image:           parse_image(:image),
        verified:        nil,
        admin:           false,
        layout_count:    15
      }
    end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end
  end
end
