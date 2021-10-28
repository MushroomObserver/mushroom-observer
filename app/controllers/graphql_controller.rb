class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session
  # skip_before_action :verify_authenticity_token
  disable_filters

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      session: session,
      # Query context goes here, for example:
      # "current_user" is a default method. MO uses "session_user" - Nimmo
      current_user: current_user,
      # Below we're making methods from application_rb available to graphql
      autologin: autologin,
      # Reminder: MO method fetches user from session, not a token. Insecure?
      # session_user: session_user
      # These require the user or obj as an arg. # Hmm - Nimmo
      # session_user_set: session_user_set,
      # check_permission: check_permission,
      # check_permission!: check_permission!,
      # reviewer?: reviewer?,
      in_admin_mode: in_admin_mode
      # unshown_notifications?: unshown_notifications?,
      # set_locale: set_locale
      # all_locales: all_locales,
      # set_timezone: set_timezone,
      # sorted_locales_from_request_header: sorted_locales_from_request_header,
      # valid_locale_from_request_header: valid_locale_from_request_header
    }
    result = MushroomObserverSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render(json: result)
  rescue StandardError => e
    raise(e) unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # https://www.howtographql.com/graphql-ruby/4-authentication/
  # gets current user from token stored in the session
  def current_user
    # if we want to change the sign-in strategy, this is the place to do it
    # if session[:user_id]
    #   puts("YES TOKEN")
    # else
    #   puts("NO TOKEN")
    #   return
    # end

    # This just pulls Rails front end's session. We can't modify this with mutations.
    # return unless session[:user_id]
    # user_id = session[:user_id]
    # user_id = Base64.decode64(session[:token]).to_i

    # Should use something like this:
    # https://www.howtographql.com/graphql-ruby/4-authentication/
    crypt = ActiveSupport::MessageEncryptor.new(Rails.application.credentials.secret_key_base.byteslice(0..31))
    puts(crypt)
    token = crypt.decrypt_and_verify(session[:token])
    user_id = token.gsub("user-id:", "").to_i

    User.safe_find(user_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
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

    render(json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: :internal_server_error)
  end
end
