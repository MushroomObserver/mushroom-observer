# frozen_string_literal: true

module Views::Layouts
  # Translator credits + edit-translation links rendered at the
  # bottom of every page by the application layout. Empty render
  # for the official language UNLESS `Language.tracking_usage?` is
  # on (admin-controlled translation-tracking mode that adds
  # per-page edit links for translators).
  class TranslatorsCredit < Views::Base
    def view_template
      lang = Language.for_locale(I18n.locale)
      return unless lang && (!lang.official || Language.tracking_usage?)

      div(id: "translators_credit", class: "hidden-print") do
        hr
        render_translators_credit(lang) unless lang.official
        render_translation_links if Language.tracking_usage?
      end
    end

    private

    def render_translators_credit(lang)
      # Translation string may contain HTML (e.g., in German)
      trusted_html(:app_translators_credit.t)
      plain(": ")

      ids_and_names = lang.top_contributors(5)
      render_contributor_links(ids_and_names)
      render_and_others_suffix(ids_and_names)

      br
    end

    def render_contributor_links(ids_and_names)
      ids_and_names.each_with_index do |(user_id, name), index|
        Link(type: :user, user: user_id, name: name)
        plain(", ") if index < ids_and_names.length - 1
      end
    end

    def render_and_others_suffix(ids_and_names)
      return unless ids_and_names.length == 5

      plain(", ")
      trusted_html(:app_translators_credit_and_others.t)
    end

    def render_translation_links
      file = Language.save_tags
      Link(type: :get, name: :app_edit_translations_on_page.t,
           target: translations_path(for_page: file),
           id: "translations_for_page_link")
      plain(" | ")
      Link(type: :get, name: :app_edit_translations.t,
           target: translations_path, id: "translations_index_link")
    end
  end
end
