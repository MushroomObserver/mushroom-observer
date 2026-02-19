# frozen_string_literal: true

require "test_helper"

class TranslationFormTest < ComponentTestCase
  def setup
    super
    @lang = languages(:english)
    @strings = @lang.localization_strings
    @tag = "two"
    @edit_tags = %w[two twos TWO TWOS]
    @official_records = build_record_map(@lang)
    @other_locales = [languages(:french), languages(:greek)]
  end

  # --- Form structure ---

  def test_renders_form_with_patch_method
    assert_html(html, "form[method='post']")
    assert_html(html, "input[name='_method'][value='patch']")
  end

  def test_renders_form_with_correct_action
    assert_html(html, "form[action='/translations/#{@tag}']")
  end

  def test_renders_form_with_translation_form_id
    assert_html(html, "form#translation_form")
  end

  def test_renders_form_with_turbo_data
    assert_html(html, "form[data-turbo='true']")
  end

  def test_renders_form_with_stimulus_controller
    assert_html(
      html, "form[data-controller='translation']"
    )
  end

  def test_renders_form_with_locale_data
    assert_html(html, "form[data-locale='#{@lang.locale}']")
  end

  def test_renders_hidden_tag_field
    assert_html(
      html,
      "input[type='hidden'][name='tag'][value='#{@tag}']"
    )
  end

  def test_renders_authenticity_token
    assert_html(
      html,
      "input[type='hidden'][name='authenticity_token']"
    )
  end

  # --- Language header ---

  def test_renders_language_header
    assert_html(
      html, "h4.font-weight-bold", text: "#{@lang.name}:"
    )
  end

  # --- Textarea fields ---

  def test_renders_textarea_for_each_edit_tag
    @edit_tags.each do |t|
      assert_html(html, "textarea[name='tag_#{t}']")
    end
  end

  def test_textarea_has_correct_value
    assert_includes(html, ">#{@strings[@tag]}</textarea>")
  end

  def test_textarea_has_stimulus_target
    assert_html(
      html,
      "textarea[data-translation-target='textarea']",
      count: 4
    )
  end

  def test_textarea_has_stimulus_action
    assert_html(
      html,
      "textarea[data-action='translation#formChanged']",
      count: 4
    )
  end

  def test_textarea_has_label
    assert_html(
      html, "label[for='tag_#{@edit_tags[0]}']",
      text: @edit_tags[0]
    )
    assert_html(
      html, "label[for='tag_#{@edit_tags[2]}']",
      text: @edit_tags[2]
    )
  end

  def test_textarea_has_form_control_class
    assert_html(
      html, "textarea.form-control[name='tag_#{@edit_tags[0]}']"
    )
  end

  # --- Between notes (plural/singular, uppercase/lowercase) ---

  def test_singular_tag_shows_singular_note
    assert_includes(
      html, :edit_translations_singular.t
    )
  end

  def test_plural_tag_shows_plural_note
    assert_includes(
      html, :edit_translations_plural.t
    )
  end

  def test_lowercase_tag_shows_lowercase_note
    assert_includes(
      html, :edit_translations_lowercase.t
    )
  end

  def test_uppercase_tag_shows_uppercase_note
    assert_includes(
      html, :edit_translations_uppercase.t
    )
  end

  # --- Buttons ---

  def test_renders_save_button
    assert_html(
      html,
      "button[type='submit'][id='save_button']",
      text: :SAVE.l
    )
  end

  def test_save_button_has_stimulus_target
    assert_html(
      html,
      "button[data-translation-target='saveButton']"
    )
  end

  def test_save_button_has_stimulus_action
    assert_html(
      html,
      "button[data-action=" \
      "'turbo:submit-start->translation#saving']"
    )
  end

  def test_renders_cancel_button
    assert_html(
      html,
      "button[type='button'][id='cancel_button']",
      text: :CANCEL.l
    )
  end

  def test_cancel_button_has_stimulus_target
    assert_html(
      html,
      "button[data-translation-target='cancelButton']"
    )
  end

  def test_renders_reload_link
    assert_html(
      html,
      "a#reload_button.btn",
      text: :RELOAD.l
    )
  end

  def test_reload_link_has_correct_href
    assert_html(
      html,
      "a#reload_button[href*='/translations/#{@tag}/edit']"
    )
  end

  def test_reload_link_has_turbo_stream
    assert_html(
      html,
      "a#reload_button[data-turbo-stream='true']"
    )
  end

  # --- Locale select ---

  def test_renders_locale_select
    assert_html(html, "select[name='locale']")
  end

  def test_locale_select_has_stimulus_target
    assert_html(
      html,
      "select[data-translation-target='localeSelect']"
    )
  end

  def test_locale_select_has_stimulus_action
    assert_html(
      html,
      "select[data-action='translation#changeLocale']"
    )
  end

  def test_locale_select_has_selected_option
    assert_html(
      html, "option[value='#{@lang.locale}'][selected]"
    )
  end

  def test_locale_select_includes_other_locales
    @other_locales.each do |lang|
      assert_html(html, "option[value='#{lang.locale}']")
    end
  end

  # --- Official section ---

  def test_official_lang_omits_official_section
    assert_no_html(html, "#translation_official")
  end

  def test_non_official_lang_renders_official_section
    non_official_html = render_form_for_lang(:french)

    assert_html(
      non_official_html, "#translation_official"
    )
    assert_html(
      non_official_html,
      "#translation_official h4",
      text: "#{Language.official.name}:"
    )
  end

  def test_non_official_lang_shows_official_text
    non_official_html = render_form_for_lang(:french)

    # Official section contains tag labels and text values
    assert_includes(non_official_html, "#{@tag}:")
    assert_html(
      non_official_html,
      "#translation_official span.underline"
    )
    assert_html(
      non_official_html,
      "#translation_official p"
    )
  end

  def test_official_text_with_trailing_newline_preserves_trailing_br
    # text stored as "line1\nline2\n" (literal \n) becomes "line1\nline2\n"
    # (actual newlines) after gsub. The trailing newline should produce a
    # trailing <br> in the rendered output.
    stub_record = Struct.new(:text).new("line1\\nline2\\n")
    official_with_trailing = @official_records.merge(@tag => stub_record)
    non_official_html = render(Components::TranslationForm.new(
                                 lang: languages(:french),
                                 tag: @tag,
                                 edit_tags: [@tag],
                                 strings: languages(:french).localization_strings,
                                 official_records: official_with_trailing
                               ))

    assert_includes(non_official_html, "line2<br>")
  end

  # --- Single tag form ---

  def test_single_tag_renders_one_textarea
    single_html = render_single_tag_form

    assert_html(
      single_html, "textarea[name='tag_one']", count: 1
    )
  end

  def test_single_tag_has_no_between_notes
    single_html = render_single_tag_form

    assert_not_includes(
      single_html, :edit_translations_plural.t
    )
    assert_not_includes(
      single_html, :edit_translations_singular.t
    )
  end

  # --- Rows calculation ---

  def test_single_tag_short_string_has_minimum_5_rows
    # Empty string: rows stays 1 (< 2), single tag → 5
    empty_strings = @strings.merge("empty_tag" => "")
    single_html = render(Components::TranslationForm.new(
                           lang: @lang,
                           tag: "empty_tag",
                           edit_tags: ["empty_tag"],
                           strings: empty_strings,
                           official_records: @official_records
                         ))

    assert_html(
      single_html,
      "textarea[name='tag_empty_tag'][rows='5']"
    )
  end

  def test_multiple_tags_textarea_has_minimum_2_rows
    assert_html(
      html, "textarea[name='tag_#{@edit_tags[0]}'][rows='2']"
    )
  end

  # --- for_page parameter ---

  def test_includes_for_page_in_action_when_present
    page_html = render_form_with_for_page("general")

    assert_html(
      page_html,
      "form[action='/translations/#{@tag}?for_page=general']"
    )
  end

  private

  def html
    @html ||= render_form
  end

  def render_form
    render(Components::TranslationForm.new(
             lang: @lang,
             tag: @tag,
             edit_tags: @edit_tags,
             strings: @strings,
             official_records: @official_records
           ))
  end

  def render_form_for_lang(lang_fixture)
    lang = languages(lang_fixture)
    strings = lang.localization_strings
    official = build_record_map(Language.official)
    two_tags = [@tag, @tag.upcase]
    edit_tags = strings.keys.select { |t| two_tags.include?(t) }
    edit_tags = two_tags if edit_tags.empty?

    render(Components::TranslationForm.new(
             lang: lang,
             tag: @tag,
             edit_tags: edit_tags,
             strings: strings,
             official_records: official
           ))
  end

  def render_single_tag_form
    render(Components::TranslationForm.new(
             lang: @lang,
             tag: "one",
             edit_tags: ["one"],
             strings: @strings,
             official_records: @official_records
           ))
  end

  def render_form_with_for_page(for_page)
    render(Components::TranslationForm.new(
             lang: @lang,
             tag: @tag,
             edit_tags: @edit_tags,
             strings: @strings,
             official_records: @official_records,
             for_page: for_page
           ))
  end

  def build_record_map(lang)
    result = {}
    lang.translation_strings.each do |str|
      result[str.tag] = str
    end
    result
  end
end
