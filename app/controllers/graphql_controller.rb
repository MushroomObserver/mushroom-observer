# frozen_string_literal: true

class GraphqlController < ApplicationController
  # Note 22/02/10 - Nimmo
  # This controller is short but important.
  # It parses the incoming request: headers for context (authentication)
  # plus the graphql query, variables, and operationName.
  #
  disable_filters

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user
      # in_admin_mode: in_admin_mode
    }
    result = MushroomObserverSchema.execute(
      query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )

    render(json: result)
  rescue StandardError => e
    raise(e) unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # https://www.howtographql.com/graphql-ruby/4-authentication/
  # Decrypt the current user from token stored in the header (not the session)
  def current_user
    ::User.get_from_token(http_auth_header)
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

  # def in_admin_mode
  #   ::User.token_in_admin_mode?(http_auth_header)
  # end

  # def autologin
  #   token_hash = ::User.decrypt_token_hash(http_auth_header)
  #   token_hash[:autologin].to_boolean
  # end

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
      # GraphQL-Ruby will validate name and type of incoming variables
      variables_param.to_unsafe_hash
    when nil
      {}
    else
      raise(ArgumentError.new("Unexpected parameter: #{variables_param}"))
    end
  end

  def handle_error_in_development(err)
    logger.error(err.message)
    logger.error(err.backtrace.join("\n"))

    render(json: { errors: [{ message: e.message, backtrace: e.backtrace }],
                   data: {} },
           status: :internal_server_error)
  end
end
