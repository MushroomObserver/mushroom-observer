# API
class API
  def parse_lang(key, args = {})
    declare_parameter(key, :lang, args)
    locale = get_param(key)
    return Language.official.locale unless locale
    lang = Language.lang_from_locale(locale)
    langs = Language.all.map(&:locale)
    langs.each do |val|
      return val if lang.casecmp(val.to_s).zero?
    end
    raise BadLimitedParameterValue.new(lang, langs)
  end
end
