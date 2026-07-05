# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Translations
  class IndexTest < ComponentTestCase
    # Stand-in for a future item type `render_item` doesn't handle yet.
    class UnknownItemType < ::TranslationsController::TranslationsUIString
    end

    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
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

    # Defensive branch guarding against a future item type being added
    # without updating `render_item` to handle it. The `index` prop is
    # typed as `_Array(TranslationsUIString)`, so the stand-in for
    # "unrecognized type" must itself be a TranslationsUIString
    # subclass — a bare Object fails Literal's type check at
    # construction, before `render_item` ever runs.
    def test_render_item_raises_for_unrecognized_type
      error = assert_raises(RuntimeError) do
        render(Index.new(
                 lang: @lang, index: [UnknownItemType.new("x")],
                 official_records: {}, translated_records: {}
               ))
      end
      assert_match(/Unexpected form item type: .*UnknownItemType/,
                   error.message)
    end

    private

    def build_records(lang, tag, text)
      return {} unless lang.translation_strings.first

      record_double = TranslationString.new(language: lang, tag: tag,
                                            text: text,
                                            updated_at: Time.zone.now)
      { tag => record_double }
    end
  end
end
