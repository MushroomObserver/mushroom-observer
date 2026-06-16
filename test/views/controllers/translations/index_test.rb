# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Translations
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      viewer = @user
      controller.define_singleton_method(:current_user) { viewer }
      controller.define_singleton_method(:in_admin_mode?) { false }
      @lang = Language.official
    end

    # Exercises every `render_item` case branch (MajorHeader,
    # MinorHeader, Comment, TagField) and `up_to_date_tag?` paths.
    def test_renders_all_item_shapes
      tag_with_string = "USE_THIS"
      strings = { tag_with_string => "translated text" }
      records = build_records(@lang, tag_with_string, "official text")
      index = [
        ::TranslationsController::TranslationsUIMajorHeader.new("MAJOR"),
        ::TranslationsController::TranslationsUIMinorHeader.new("Minor head"),
        ::TranslationsController::TranslationsUIComment.new("a comment"),
        ::TranslationsController::TranslationsUITagField.new(tag_with_string)
      ]
      html = render(Index.new(
                      lang: @lang,
                      tag: tag_with_string,
                      index: index,
                      strings: strings,
                      edit_tags: [tag_with_string],
                      official_records: records,
                      translated_records: records
                    ))
      assert_html(html, "p.major_header")
      assert_html(html, "p.minor_header")
      assert_html(html, "p.comment")
      assert_html(html, "p.tag_field")
    end

    private

    def build_records(lang, tag, text)
      record = lang.translation_strings.first || (return {})
      record_double = TranslationString.new(language: lang, tag: tag,
                                            text: text,
                                            updated_at: Time.zone.now)
      { tag => record_double }
    end
  end
end
