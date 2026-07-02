# frozen_string_literal: true

module Views::Controllers::Info
  # Translators' note + language picker.
  class TranslatorsNote < Views::FullPageBase
    prop :languages, _Array(::Language)

    def view_template
      add_page_title(:translators_note_title.l)

      trusted_html(:translators_note.tpl(
                     repo: "#{MO.code_repository}/mushroom-observer/" \
                           "blob/main/config/locales/en.txt"
                   ))

      ul { @languages.each { |lang| render_lang(lang) } }
    end

    private

    def render_lang(lang)
      li do
        link_to(lang.name, reload_with_args(user_locale: lang.locale))
        if lang.beta
          whitespace
          span { "(beta)" }
        end
      end
    end
  end
end
