# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'login_system'

CSS = ['Agaricus', 'Amanita', 'Cantharellaceae', 'Hygrocybe']
SVN_REPOSITORY = "http://svn.collectivesource.com/mushroom_sightings"

module Enumerable
  def select_rand
    tmp = self.to_a
    tmp[Kernel.rand(tmp.size)]
  end
end

def rand_char(str)
  sprintf("%c", str[Kernel.rand(str.length)])
end

def random_password(len)
  result = ''
  for n in (0..len)
    result += rand_char('abcdefghijklmnopqrstuvwxyz0123456789')
  end
  result
end

module ActiveRecord
    class Base
        def self.find_by_sql_with_limit(sql, offset, limit)
            sql = sanitize_sql(sql)
            add_limit!(sql, {:limit => limit, :offset => offset})
            find_by_sql(sql)
        end

        def self.count_by_sql_wrapping_select_query(sql)
            sql = sanitize_sql(sql)
            count_by_sql("select count(*) from (#{sql}) as my_table")
        end
   end
end

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include LoginSystem

  around_filter :set_locale
  
  before_filter(:disable_link_prefetching, :only => [
     # account_controller methods
    :logout_user, :delete, :signup,
    
    # observer_controller methods
    :destroy_observation, :destroy_image,
    :destroy_comment, :destroy_species_list, :upload_image])

  def paginate_by_sql(model, sql, per_page, options={})
    if options[:count]
        if options[:count].is_a? Integer
            total = options[:count]
        else
            total = model.count_by_sql(options[:count])
        end
    else
        total = model.count_by_sql_wrapping_select_query(sql)
    end

    object_pages = Paginator.new self, total, per_page,
         @params['page']
    objects = model.find_by_sql_with_limit(sql,
         object_pages.current.to_sql[1], per_page)
    return [object_pages, objects]
  end

  helper_method :check_permission
  def check_permission(user_id)
    user = session['user']
    !user.nil? && user.verified && ((user_id == session['user'].id) || (session['user'].id == 0))
  end

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash[:notice] = 'Permission denied.'
    end
    result
  end

  def verify_user()
    result = false
    if session['user'].verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => session['user'].id
    else
      result = true
    end
    result
  end

  private
  
    def disable_link_prefetching
      if request.env["HTTP_X_MOZ"] == "prefetch" 
        logger.debug "prefetch detected: sending 403 Forbidden" 
        render_nothing "403 Forbidden" 
        return false
      end
    end

    # Set the locale from the parameters, the session, or the navigator
    # If none of these works, the Globalite default locale is set (en-*)
    def set_locale
      # Get the current path and request method (useful in the layout for changing the language)
      @current_path = request.env['PATH_INFO']
      @request_method = request.env['REQUEST_METHOD']

      # Try to get the locale from the parameters, from the session, and then from the navigator
      if params[:user_locale]
        logger.debug "[globalite] #{params[:user_locale][:code]} locale passed"
        Locale.code = params[:user_locale][:code] #get_matching_ui_locale(params[:user_locale][:code]) #|| session[:locale] || get_valid_lang_from_accept_header || Globalite.default_language
        # Store the locale in the session
        session[:locale] = Locale.code
      elsif session[:locale]
        logger.debug "[globalite] loading locale: #{session[:locale]} from session"
        Locale.code = session[:locale]
      else
        # Changed code from Globalite sample app since Locale.code= didn't like 'pt-br'
        # but did like 'pt-BR'.  standardize_locale was added to take a locale spec
        # and enforce this standard.
        locale = standardize_locale(get_valid_lang_from_accept_header)
        logger.debug "[globalite] found a valid http header locale: #{locale}"
        Locale.code = locale
      end

      # Add a last gasp default if the selected locale doesn't match any of our
      # existing translations.
      if :app_title.l == '__localization_missing__'
        logger.warn("No translation exists for: #{Locale.code}")
        Locale.code = "en-US"
      end
      
      # Locale.code = "en-US"
      logger.debug "[globalite] Locale set to #{Locale.code}"
      # render the page
      yield

      # reset the locale to its default value
      Locale.reset!
    end

    # Get a sorted array of the navigator languages
    def get_sorted_langs_from_accept_header
      accept_langs = (request.env['HTTP_ACCEPT_LANGUAGE'] || "en-us,en;q=0.5").split(/,/) rescue nil
      return nil unless accept_langs

      # Extract langs and sort by weight
      # Example HTTP_ACCEPT_LANGUAGE: "en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3"
      wl = {}
      accept_langs.each {|accept_lang|
          if (accept_lang + ';q=1') =~ /^(.+?);q=([^;]+).*/
              wl[($2.to_f rescue -1.0)]= $1
          end
      }
      logger.debug "[globalite] client accepted locales: #{wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }.to_sentence}"
      sorted_langs = wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }
    end

    # Returns a valid language that best suits the HTTP_ACCEPT_LANGUAGE request header.
    # If no valid language can be deduced, then <tt>nil</tt> is returned.
    def get_valid_lang_from_accept_header
      # Get the sorted navigator languages and find the first one that matches our available languages
      get_sorted_langs_from_accept_header.detect{|l| get_matching_ui_locale(l) }
    end

    # standardize_locale was added to take a locale spec and enforce the standard that
    # the lang be lower case and the country be upper case.  The Globalite Locale.code=
    # method seems to expect this standard, but Firefox uses all lower case.
    def standardize_locale(locale)
      lang = locale[0,2].downcase
      country = '*'
      if locale[3,5]
        country = locale[3,5].upcase
      end
      result = "#{lang}-#{country}".to_sym
      logger.debug "[globalite] trying to match #{result}"
      result
    end
    
    # Returns the UI locale that best matches with the parameter
    # or nil if not found
    def get_matching_ui_locale(locale)
      lang = locale[0,2].downcase
      if locale[3,5]
        country = locale[3,5].upcase
        logger.debug "[globalite] trying to match locale: #{lang}-#{country}"
        locale_code = "#{lang}-#{country}".to_sym
      else
        logger.debug "[globalite] trying to match #{lang}-*"
        locale_code = "#{lang}-*".to_sym
      end

      # Check with exact matching
      if Globalite.ui_locales.values.include?(locale)
        logger.debug "[globalite] Globalite does include #{locale}"
        locale_code
      end

      # Check on the language only
      Globalite.ui_locales.values.each do |value|
        value.to_s =~ /#{lang}-*/ ? value : nil
      end
    end

end
