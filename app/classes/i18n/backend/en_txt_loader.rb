# frozen_string_literal: true

# Loads config/locales/en.txt's tag/text pairs into a backend under MO's
# locale namespace (config.locale_namespace, "mo"), English locale only.
#
# Populates the gem_file_backend (Chain's third, last-resort backend --
# see config/initializers/i18n_backend.rb) with English content that a
# `.t` call can resolve even before TranslationString/Solid Cache have
# anything -- most importantly, a `.t` call evaluated at class-load time
# (e.g. a `validates message:`), which runs once per process and bakes
# in whatever the backend resolved at that instant. Being last in the
# Chain, this cannot shadow a live DB/cache value; it only fills what
# would otherwise render as a bracketed tag.
class I18n::Backend::EnTxtLoader
  def self.call(backend)
    en_txt_path = Rails.root.join("config/locales/en.txt")
    data = YAML.safe_load_file(en_txt_path, permitted_classes: [Symbol])
    backend.store_translations(
      :en,
      { MO.locale_namespace.to_sym =>
          data.select { |_tag, text| text.is_a?(String) } }
    )
    backend
  end
end
