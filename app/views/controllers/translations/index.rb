# frozen_string_literal: true

module Views::Controllers::Translations
  # Translations index — list of tags + headers on the left, edit
  # form + version history on the right.
  class Index < Views::FullPageBase
    prop :lang, ::Language
    prop :tag, _Nilable(::String), default: nil
    prop :for_page, _Nilable(::String), default: nil
    prop :index, _Array(::TranslationsController::TranslationsUIString)
    prop :strings, _Hash(::String, ::String), default: -> { {} }
    prop :edit_tags, _Array(::String), default: -> { [] }
    prop :official_records,
         _Hash(::String, ::TranslationString), default: -> { {} }
    prop :translated_records,
         _Hash(::String, ::TranslationString), default: -> { {} }

    def view_template
      container_class(:wide)
      add_page_title(:edit_translations_title.t)
      render_help_block
      div(class: "row") do
        div(class: "col-xs-6 translation_container") { render_index_panel }
        div(class: "col-xs-6 translation_container") { render_ui_panel }
      end
    end

    private

    def render_help_block
      div(class: "container-text") do
        render(::Components::Help::Block.new(:p, :edit_translations_help.t))
      end
    end

    def render_index_panel
      div(id: "translations_index") do
        @index.each { |item| render_item(item) }
      end
    end

    def render_ui_panel
      div(id: "translation_ui") do
        if @edit_tags.any?
          render(Form.new(lang: @lang, tag: @tag, edit_tags: @edit_tags,
                          strings: @strings, for_page: @for_page,
                          official_records: @official_records))
        end
        render(Versions.new(edit_tags: @edit_tags,
                            translated_records: @translated_records,
                            user: current_user))
      end
    end

    def render_item(item)
      case item
      when ::TranslationsController::TranslationsUIMajorHeader
        render_header_paragraph(item.string, "major_header")
      when ::TranslationsController::TranslationsUIMinorHeader
        render_header_paragraph(item.string, "minor_header")
      when ::TranslationsController::TranslationsUIComment
        render_header_paragraph(item.string, "comment")
      when ::TranslationsController::TranslationsUITagField
        render_tag_field(item.ttag)
      else
        raise("Unexpected form item type: #{item.class.name}")
      end
    end

    def render_header_paragraph(string, css_class)
      p(class: css_class) do
        string.to_s.split('\n').each_with_index do |line, idx|
          br if idx.positive?
          plain(line)
        end
      end
    end

    def render_tag_field(ttag)
      str = preview_string(@strings[ttag])
      p(class: "tag_field") do
        link_to(edit_translation_path(id: ttag, locale: @lang.locale),
                data: { tag: ttag, role: "show_tag", turbo_stream: true }) do
          span(class: "tag") { "#{ttag}:" }
        end
        whitespace
        span(class: tag_str_class(ttag), id: "str_#{ttag}") { plain(str) }
      end
    end

    def tag_str_class(ttag)
      up_to_date_tag?(ttag) ? "translated text-muted" : "font-weight-bold"
    end

    def up_to_date_tag?(ttag)
      translated = @translated_records[ttag]
      official = @official_records[ttag]
      return true if translated && official &&
                     translated.updated_at >= official.updated_at - 1.second
      return true if official&.text&.match(/\A\[:?\w[^\[\]'"]*\]\Z/)

      false
    end

    def preview_string(str, limit = 250)
      str = @lang.clean_string(str.to_s)
      str = str.gsub("\n", " / ")
      str = "#{str[0..limit]}..." if str.length > limit
      str
    end
  end
end
