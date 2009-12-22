################################################################################
#
#  This controller handles XML interface.
#
#  Views:
#    observations       Get and post observations.
#    images             Get and post images.
#    names              Get and post name descriptions.
#    locations          Get and post location descriptions.
#
#  Helpers:
#    authenticate               Check user's authentication.
#    get_param(name)            Pull parameter out of request if given
#    error_if_any_other_params  Raise errors for all unused parameters.
#    build_query(...)           Build sequel query (???)
#    paginate(object_list)      Paginate results.
#
################################################################################

class MoApiException < Exception
  attr_accessor :code, :msg, :fatal

  def title
    case code
    when 101 ; 'bad request type'
    when 102 ; 'bad request syntax'
    when 201 ; 'object not found'
    when 301 ; 'authentication failed'
    when 501 ; 'internal error'
    else       'unknown error'
    end
  end
end

class DatabaseController < ApplicationController
  def observations
    @start_time = Time.now
    @observations = []
    @errors = []
    begin
      case request.method
      when :get
        if ids = parse_id_param
          @observations = Observation.find_all(:conditions => "id IN (#{ids.join(',')})")
          for id in ids - @observations.map {|o| o.id}
            @errors << error(201, "Observation not found: '#{id}'")
          end
          error_if_any_other_params
        else
          raise error(101, 'Only request-by-ID available at the moment.')
          # user      = get_param(:user)
          # date      = get_param(:datetime)
          # location  = get_param(:location)
          # name      = get_param(:name)
          # notes     = get_param(:notes)
          # image_id  = get_param(:image_id)
          # has_image = get_param(:has_image)
          # has_specimen = get_param(:has_specimen)
          # is_collection_location = get_param(:is_collection_location)
          # query = build_query(...)
          # @observations = ...
          # paginate(@observations)
          # error_if_any_other_params
        end
      when :post
        raise error(101, 'POST methods not available yet.')
        # authenticate
      else
        raise error(101, "Invalid request method; valid values: 'GET' and 'POST'")
      end
    rescue => e
      e = error(501, e.to_s) if !e.is_a?(MoApiException)
      e.fatal = true
      @errors << e
    end
  end

  # Check user's authentication.
  def authenticate
    result = nil
    auth_id   = get_param(:auth_id)
    auth_code = get_param(:auth_code)
    begin
      user = User.find(auth_id.to_i)
      if user.auth_code == auth_code
        result = user
      else
        raise error(301, 'Authentication failed: invalid auth_code.')
      end
    rescue
      raise error(301, 'Authentication failed: invalid auth_id.')
    end
    return result
  end

  # Pull parameter out of request if given.
  def get_param(name)
    @used ||= {}
    result = nil
    if params[name].to_s != ''
      @used[name.to_s] = true
      result = params[name]
    end
    return result
  end

  # Parse id parameter.  Returns array of integers.  Valid syntaxes are:
  #   1234
  #   1234,2345,...
  #   1234-1239,...
  def parse_id_param
    result = nil
    if ids = get_param(:id)
      for x in ids.split(',')
        if x.match(/^\d+$/)
          a = x.to_i
          if a < 1 || a > 1e9
            raise error(102, "ID out of range: '#{a}'")
          else
            result << a
          end
        elsif x.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          if a < 1 || a > 1e9
            raise error(102, "ID out of range: '#{a}'")
          elsif b < 1 || b > 1e9
            raise error(102, "ID out of range: '#{b}'")
          elsif b - a > 1e3
            raise error(102, "ID range too large: '#{a}-#{b}' (max is 1000)")
          else
            result += (a..b).to_a
          end
        else
          raise error(102, 'Invalid syntax for ID parameter.')
        end
      end
    end
    return result
  end

  # Raise errors for all unused parameters.
  def error_if_any_other_params
    for key in params.keys
      if !@used[key.to_s]
        @errors << error(102, "Unrecognized argument: '#{key}' (ignored)")
      end
    end
  end

  # # Build sequel query (???)
  # def build_query(...)
  # end
  #
  # # Paginate results.
  # def paginate(object_list)
  #   first  = get_param(:first)
  #   last   = get_param(:last)
  #   number = get_param(:number)
  #   ...
  # end

  def error(code, msg, fatal=false)
    MoApiException.new(
      :code => code,
      :msg => msg,
      :fatal => fatal
    )
  end
end
