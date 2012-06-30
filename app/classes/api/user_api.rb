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
      :image,
    ]

    def query_params
      {
        :where    => sql_id_condition,
        :created  => parse_time_ranges(:created),
        :modified => parse_time_ranges(:modified),
      }
    end

    def create_params
      password = parse_string(:password, :limit => 80, :default => String.random(8))
      {
        :login           => parse_string(:login, :limit => 80),
        :name            => parse_string(:name, :limit => 80, :default => ''),
        :email           => parse_email(:email, :limit => 80),
        :locale          => parse_enum(:locale, :limit => Language.all.map(&:locale),
                                       :default => Language.official.locale),
        :notes           => parse_string(:notes, :default => ''),
        :mailing_address => parse_string(:mailing_address, :default => ''),
        :license         => parse_license(:license, :default =>  License.preferred),
        :location        => parse_location(:location),
        :image           => parse_image(:image),
        :verified        => nil,
        :admin           => false,
        :created_here    => true,
        :rows            => 5,
        :columns         => 3,
        :password        => password,
        :password_confirmation => password,
      }
    end

    def validate_create_params!(params)
      unless login = params[:login]
        raise MissingParameter.new(:arg => :login)
      end
      if User.find_by_login(login)
        raise UserAlreadyExists.new(login)
      end
      if not params[:email]
        raise MissingParameter.new(:arg => :email)
      end
    end

    def after_create(user)
      key = ApiKey.new(:notes => @api_key.notes, :user => user)
      key.provide_defaults
      key.save
      user.reload
    end

    def put
      raise NoMethodForAction(:put, action)
    end

    def delete
      raise NoMethodForAction(:delete, action)
    end
  end
end
