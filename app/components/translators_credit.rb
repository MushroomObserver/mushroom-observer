# frozen_string_literal: true

module Components
  # Renders credit to translators at bottom of pages for non-official languages
  # and/or edit translation links when tracking translation usage
  #
  # @example Basic usage in layout
  #   <%= render(Components::TranslatorsCredit.new) %>
  #
  class TranslatorsCredit < Base
    def view_template
      lang = Language.find_by(locale: I18n.locale)
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
        a(href: user_path(user_id), class: "user_link_#{user_id}") do
          plain(name)
        end
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
      a(
        href: translations_path(for_page: file),
        id: "translations_for_page_link"
      ) { :app_edit_translations_on_page.t }
      plain(" | ")
      a(
        href: translations_path,
        id: "translations_index_link"
      ) { :app_edit_translations.t }
    end
  end
end
