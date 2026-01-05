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

    # rubocop:disable Metrics/AbcSize
    def render_translators_credit(lang)
      plain(:app_translators_credit.t)
      plain(": ")

      ids_and_names = lang.top_contributors(5)

      ids_and_names.each_with_index do |(user_id, name), index|
        a(href: user_path(user_id), class: "user_link_#{user_id}") do
          plain(name)
        end
        plain(", ") if index < ids_and_names.length - 1
      end

      if ids_and_names.length == 5
        plain(", ")
        plain(:app_translators_credit_and_others.t)
      end

      br
    end
    # rubocop:enable Metrics/AbcSize

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
