class Locale
  attr_reader :language, :country, :code

  #
  def self.language
    Globalite.language
  end

  # Return the country
  def self.country
    Globalite.country
  end

  # Return the user's locale or the system's if the user doesn't have one set
  def self.code
    "#{Globalite.language}-#{Globalite.country}".to_sym
  end
  
  def self.set_code(locale)
    lang, country = locale.to_s.split('-')
    if country # Make sure locale is of the form <lang>-<country>
      if Globalite.languages.include?(lang.to_sym) # Is this a known language
        Globalite.language = lang.to_sym # then use it
        if Globalite.locales.include?(locale.to_sym) # Is this a known locale
          Globalite.country = country.to_sym # then use the country as well
        else
          Globalite.country = :* # else use the generic version of this language
        end
      end
    end
  end
  
  def self.code=(locale)
    self.set_code(locale)
  end
  
  # Return the available locales
  def self.codes
    Globalite.locales
  end
  
  # Return the locale name in its own language for instance fr-FR => Français
  def self.name(locale)
    Globalite.locale_name(locale)
  end
  
  # Return the list of the UI locales with their name
  def self.ui_locales
    Globalite.ui_locales
  end
  
  # Return the list of the Rails locales with their name 
  def self.rails_locales
    Globalite.rails_locales
  end

  # Reset the Locale to the default settings
  def self.reset!
    Locale.set_code("#{Globalite.default_language}-#{Globalite.default_country}")
  end
  
end
