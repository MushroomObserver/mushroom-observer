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

class DatabaseController < ApplicationController
  def observations
    @observations = []
    @errors = []
    case request.method
    when :get
      if params[:id].to_s != ''
        for id in params[:id].split(',')
          @observations << Observation.find(id.to_i)
        rescue
          @errors << "101 - No observation with ID ##{id}."
        end
      else
#         user      = get_param(:user)
#         date      = get_param(:datetime)
#         location  = get_param(:location)
#         name      = get_param(:name)
#         notes     = get_param(:notes)
#         image_id  = get_param(:image_id)
#         has_image = get_param(:has_image)
#         has_specimen = get_param(:has_specimen)
#         is_collection_location = get_param(:is_collection_location)
#         query = build_query(...)
#         @observations = ...
#         paginate(@observations)
#         @errors += error_if_any_other_params
        @errors << '100 - Only request-by-ID available at the moment.'
      end
    when :post
      @errors << '100 - POST methods not available yet.'
#       if !authenticate
#         @errors << '102 - Must be logged in or provide authentication to POST.'
#       else
#       end
    else
      @errors << '100 - Invalid request method; valid values: "GET" and "POST"'
    end
  end

  # Check user's authentication.
  def authenticate
    result = nil
    auth_id   = get_param(:auth_id)
    auth_code = get_param(:auth_code)
    begin
      user = User.find(auth_id.to_i)
      result = user if user.auth_code == auth_code
    rescue
    end
    @errors << '103 - Authentication failed.' if !result
    return result
  end

#   # Pull parameter out of request if given
#   def get_param(name)
#   end
# 
#   # Raise errors for all unused parameters.
#   def error_if_any_other_params
#   end
# 
#   # Build sequel query (???)
#   def build_query(...)
#   end
# 
#   # Paginate results.
#   def paginate(object_list)
#     first  = get_param(:first)
#     last   = get_param(:last)
#     number = get_param(:number)
#     ...
#   end
end
