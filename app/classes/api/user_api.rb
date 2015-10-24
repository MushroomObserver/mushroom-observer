# encoding: utf-8

class API
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
        updated_at: parse_time_range(:updated_at),
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
        login: parse_string(:login, limit: 80),
        name: parse_string(:name, limit: 80, default: ""),
        email: parse_email(:email, limit: 80),
        locale: parse_lang(:locale),
        notes: parse_string(:notes, default: ""),
        mailing_address: parse_string(:mailing_address, default: ""),
        license: parse_license(:license, default: License.preferred),
        location: parse_location(:location),
        image: parse_image(:image),
        verified: nil,
        admin: false,
        created_here: true,
        layout_count: 15
      }
    end

    def validate_create_params!(params)
      unless login = params[:login]
        fail MissingParameter.new(arg: :login)
      end
      fail UserAlreadyExists.new(login) if User.find_by_login(login)
      fail MissingParameter.new(arg: :email) unless params[:email]
    end

    def after_create(user)
      if @create_key
        key = ApiKey.new(notes: @create_key, user: user)
        key.provide_defaults
        key.verified = nil
        key.save
        user.reload
      end
    end

    def put
      fail NoMethodForAction("PUT", action)
    end

    def delete
      fail NoMethodForAction("DELETE", action)
    end
  end
end
