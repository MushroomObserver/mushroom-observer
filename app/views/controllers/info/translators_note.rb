# frozen_string_literal: true

module Views::Controllers::Info
  # Translators' note + language picker.
  class TranslatorsNote < Views::Base
    def view_template
      add_page_title(:translators_note_title.l)

      trusted_html(:translators_note.tpl(
                     repo: "#{MO.code_repository}/mushroom-observer/" \
                           "blob/main/config/locales/en.txt"
                   ))

      ul do
        ::Language.all.sort_by(&:order).each { |lang| render_lang(lang) }
      end
    end

    private

    def render_lang(lang)
      li do
        link_to(lang.name, reload_with_args(user_locale: lang.locale))
        if lang.beta
          plain(" ")
          span { "(beta)" }
        end
      end
    end
  end
end
