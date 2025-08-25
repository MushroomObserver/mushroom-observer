# frozen_string_literal: true

#  ==== Internationalization
#  all_locales::            Array of available locales for which we have
#                           translations.
#  set_locale::             (filter: determine which locale is requested)
#  set_timezone::           (filter: Set timezone from cookie set by client's
#                            browser.)
#  sorted_locales_from_request_header::
#                           (parse locale preferences from request header)
#  valid_locale_from_request_header::
#                           (choose locale that best matches request header)
#
module ApplicationController::Internationalization
  ##############################################################################
  #
  #  :section: Internationalization
  #
  ##############################################################################

  # Before filter: Decide which locale to use for this request.  Sets the
  # Globalite default.  Tries to get the locale from:
  #
  # 1. parameters (user clicked on language in bottom left)
  # 2. user prefs (user edited their preferences)
  # 3. session (whatever we used last time)
  # 4. navigator (provides default)
  # 5. server (MO.default_locale)
  #
  def set_locale
    lang = Language.find_by(locale: specified_locale) || Language.official

    # Only change the Locale code if it needs changing.  There is about a 0.14
    # second performance hit every time we change it... even if we're only
    # changing it to what it already is!!
    change_locale_if_needed(lang.locale)

    # Update user preference.
    @user.update(locale: lang.locale) if @user && @user.locale != lang.locale

    logger.debug("[I18n] Locale set to #{I18n.locale}")

    # Tell Rails to continue to process request.
    true
  end

  def specified_locale
    params_locale || prefs_locale || session_locale || browser_locale
  end

  def params_locale
    return unless params[:user_locale]

    logger.debug("[I18n] loading locale: #{params[:user_locale]} from params")
    params[:user_locale]
  end

  def prefs_locale
    return unless @user&.locale.present? && params[:controller] != "ajax"

    logger.debug("[I18n] loading locale: #{@user.locale} from @user")
    @user.locale
  end

  def session_locale
    return unless session[:locale]

    logger.debug("[I18n] loading locale: #{session[:locale]} from session")
    session[:locale]
  end

  def browser_locale
    return unless (locale = valid_locale_from_request_header)

    logger.debug("[I18n] loading locale: #{locale} from request header")
    locale
  end

  def change_locale_if_needed(new_locale)
    return if I18n.locale.to_s == new_locale

    I18n.locale = new_locale
    session[:locale] = new_locale
  end

  # Before filter: Set timezone based on cookie set in application layout.
  def set_timezone
    tz = cookies[:tz]
    if tz.present?
      begin
        Time.zone = tz
      rescue StandardError
        logger.warn("TimezoneError: #{tz.inspect}")
      end
    end
    @js = js_enabled?(tz)
  end

  # Until we get rid of reliance on @js, this is a surrogate for
  # testing if the client's JS is enabled and sufficiently fully-featured.
  def js_enabled?(time_zone)
    time_zone.present? || Rails.env.test?
  end

  # Return Array of the browser's requested locales (HTTP_ACCEPT_LANGUAGE).
  # Example syntax:
  #
  #   en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3
  #
  def sorted_locales_from_request_header
    accepted_locales = request.env["HTTP_ACCEPT_LANGUAGE"]
    logger.debug("[globalite] HTTP header = #{accepted_locales.inspect}")
    return [] if accepted_locales.blank?

    locale_weights = map_locales_to_weights(accepted_locales)
    # Sort by decreasing weights.
    result = locale_weights.sort { |a, b| b[1] <=> a[1] }.pluck(0)
    logger.debug("[globalite] client accepted locales: #{result.join(", ")}")
    result
  end

  # Extract locales and weights, creating map from locale to weight.
  def map_locales_to_weights(locales)
    locales.split(",").each_with_object({}) do |term, loc_wts|
      next unless "#{term};q=1" =~ /^(.+?);q=([^;]+)/

      loc_wts[Regexp.last_match(1)] = (begin
                                         Regexp.last_match(2).to_f
                                       rescue StandardError
                                         -1.0
                                       end)
    end
  end

  # Returns our locale that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # Returns a String, or <tt>nil</tt> if no valid match found.
  def valid_locale_from_request_header
    # Get list of languages browser requested, sorted in the order it prefers
    # them.
    requested_locales = sorted_locales_from_request_header.map do |locale|
      if locale =~ /^(\w\w)-(\w+)$/
        Regexp.last_match(1).downcase
      else
        locale.downcase
      end
    end

    # Lookup the closest match based on the given request priorities.
    lookup_valid_locale(requested_locales)
  end

  # Lookup the closest match based on the given request priorities.
  def lookup_valid_locale(requested_locales)
    requested_locales.each do |locale|
      logger.debug("[globalite] trying to match locale: #{locale}")
      language = locale.split("-").first
      next unless I18n.available_locales.include?(language.to_sym)

      logger.debug("[globalite] language match: #{language}")
      return language
    end
    "en"
  end

  private :js_enabled?, :map_locales_to_weights, :lookup_valid_locale
end
