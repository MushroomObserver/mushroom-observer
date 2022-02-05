# frozen_string_literal: true

class GraphqlController < ApplicationController
  # Note 22/01/29 - Nimmo
  # This controller is short but important, and I haven't figured it out yet.
  # It parses the incoming request: headers, context (including authentication)
  # plus the graphql query, variables, and operationName.
  #
  # JWT is a popular way to do auth, but i'm experimenting for now with Rails
  # built-in token generation. There are examples in the wild and i think
  # it should be fine for us.
  #
  # (Below deactivates csrf for development, I don't believe necessary)
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session
  # skip_before_action(:verify_authenticity_token)
  # skip_before_action(:fix_bad_domains)
  disable_filters

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user,
      # Below maybe methods from application_rb available to graphql? Not yet
      autologin: autologin,
      in_admin_mode: in_admin_mode
    }
    result = MushroomObserverSchema.execute(query, variables: variables, context: context, operation_name: operation_name)

    # This is for my sanity, to be removed prior to merge - Nimmo
    puts("context")
    pp(context)

    render(json: result)
  rescue StandardError => e
    raise(e) unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # https://www.howtographql.com/graphql-ruby/4-authentication/
  # Decrypt the current user from token stored in the header (not the session)
  def current_user
    # if we want to change the sign-in strategy, this is the place to do it

    crypt = ActiveSupport::MessageEncryptor.new(Rails.application.credentials.secret_key_base.byteslice(0..31))
    # token = crypt.decrypt_and_verify(session[:token])

    token = crypt.decrypt_and_verify(http_auth_header)
    user_id = token.gsub("user-id:", "").to_i

    User.safe_find(user_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  # https://www.pluralsight.com/guides/token-based-authentication-with-ruby-on-rails-5-api
  def http_auth_header
    headers = request.headers
    if headers["authorization"].present?
      return headers["authorization"].split(" ").last
      # else
      # Don't error if there's no token, we're just checking
      # errors.add(:token, "Missing token")
      # raise(ArgumentError.new("Missing token"))
    end

    nil
  end

  def in_admin_mode
    # crypt = ActiveSupport::MessageEncryptor.new(Rails.application.credentials.secret_key_base.byteslice(0..31))
    # token = crypt.decrypt_and_verify(session[:token])
    # in_admin_mode = token.gsub("in_admin_mode:", "").to_boolean
    false
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise(ArgumentError.new("Unexpected parameter: #{variables_param}"))
    end
  end

  def handle_error_in_development(e)
    logger.error(e.message)
    logger.error(e.backtrace.join("\n"))

    render(json: { errors: [{ message: e.message, backtrace: e.backtrace }],
                   data: {} },
           status: :internal_server_error)
  end
end
