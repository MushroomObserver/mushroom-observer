# frozen_string_literal: true

require("test_helper")

class TranslationsControllerTest < FunctionalTestCase
  # Translation pages use many tags not in test locale files.
  # Clear missing_tags to avoid false positives in teardown.
  def teardown
    Symbol.missing_tags = []
    super
  end

  def mock_template
    [
      "---\n",
      " garbage \n",
      "##################################\n",
      "\n",
      "# IMPORTANT STUFF\n",
      "\n",
      "# Main Objects:\n",
      "image: image\n",
      "name: name\n",
      "user: user\n",
      "\n",
      "# Actions:\n",
      "prev: Prev\n",
      "# ignore this comment\n",
      "next: Next\n",
      "index: Index\n",
      "show_object: Show [type]\n",
      "\n",
      "##################################\n",
      "\n",
      "# MAIN PAGES\n",
      "\n",
      "# observations/index\n",
      "index_title: Main Index\n",
      "# you don't see this every day\n",
      "index_error: An unusual error occurred\n",
      "index_help: >\n",
      "  This page shows an index of objects.\n",
      "\n",
      "index_prefs: Your Account\n",
      "\n",
      "# account/preferences/edit\n",
      "prefs_title: Your Account\n",
      "\n"
    ].join
  end

  def hashify(*args)
    args.index_with { |_arg| true }
  end

  def assert_major_header(str, item)
    assert(item.is_a?(TranslationsController::TranslationsUIMajorHeader))
    assert_equal(str, item.string)
  end

  def assert_minor_header(str, item)
    assert(item.is_a?(TranslationsController::TranslationsUIMinorHeader))
    assert_equal(str, item.string)
  end

  def assert_comment(str, item)
    assert(item.is_a?(TranslationsController::TranslationsUIComment))
    assert_equal(str, item.string)
  end

  def assert_tag_field(tag, item)
    assert(item.is_a?(TranslationsController::TranslationsUITagField))
    assert_equal(tag, item.ttag)
  end

  ##############################################################################

  def test_index_with_page
    Language.track_usage
    :name.l
    assert_equal(["name"], Language.tags_used)
    page = Language.save_tags
    get(:index, params: { for_page: page })
  end

  def test_primary_tag
    lang = languages(:english)
    strings = lang.localization_strings
    assert(strings.length >= 8)
    assert_equal("one", @controller.primary_tag("one", strings))
    assert_equal("two", @controller.primary_tag("two", strings))
    assert_equal("two", @controller.primary_tag("Two", strings))
    assert_equal("two", @controller.primary_tag("TWOS", strings))
    assert_equal("two", @controller.primary_tag("tWoS", strings))
    assert_equal("four", @controller.primary_tag("FoUr", strings))
  end

  def test_build_index
    lang = languages(:english)
    file = mock_template

    form = @controller.build_index(lang, hashify, file)
    assert_equal([], form)

    form = @controller.build_index(lang, hashify("name"), file)
    assert_major_header("IMPORTANT STUFF", form.shift)
    assert_minor_header("Main Objects:", form.shift)
    assert_tag_field("name", form.shift)
    assert(form.empty?)

    form = @controller.build_index(lang, hashify("index", "index_help"), file)
    assert_major_header("IMPORTANT STUFF", form.shift)
    assert_minor_header("Actions:", form.shift)
    assert_tag_field("index", form.shift)
    assert_major_header("MAIN PAGES", form.shift)
    assert_minor_header("observations/index", form.shift)
    assert_tag_field("index_title", form.shift)
    assert_comment("you don't see this every day", form.shift)
    assert_tag_field("index_error", form.shift)
    assert_tag_field("index_help", form.shift)
    assert_tag_field("index_prefs", form.shift)
    assert(form.empty?)
  end

  def test_authorization_no_login_en
    get(:index, params: { locale: "en" })
    assert_response(:redirect)
  end

  def test_authorization_no_login_el
    get(:index, params: { locale: "el" })
    assert_response(:redirect)
  end

  def test_authorization_user_en
    login("mary")
    get(:index, params: { locale: "en" })
    assert_flash_error
    assert_response(:redirect)
  end

  def test_authorization_zero_user
    login("zero_user")
    get(:index, params: { locale: "en" })
    assert_flash_error
    assert_response(:redirect)
  end

  def test_authorization_user_bad_locale
    login("mary")
    get(:index, params: { locale: "bad" })
    assert_flash_error
    assert_response(:redirect)
  end

  def test_authorization_user_el
    login("mary")
    get(:index, params: { locale: "el" })
    assert_no_flash
    assert_response(:success)
  end

  def test_authorization_admin_en
    login("rolf")
    get(:index, params: { locale: "en" })
    assert_no_flash
    assert_response(:success)
  end

  def test_index
    login("rolf")
    get(:index)
    assert_no_flash
    assert_response(:success, locale: "en")
    assert_select("input[type=submit]", text: :SAVE.l, count: 0)
  end

  def test_page_expired
    login("rolf")
    make_admin

    Language.track_usage
    :all.l
    :none.l
    page = Language.save_tags

    # Page is good, should only display the two tags used above.
    get(:index, params: { locale: "en", for_page: page })
    assert_no_flash
    assert_equal(2, assigns(:show_tags).length)

    # Simulate page expiration:
    # result is it will display all tags, not just the two used above.
    get(:index, params: { locale: "en", for_page: "xxx" })
    assert_flash_error
    assert(assigns(:show_tags).length > 2)
  end

  # ----------------------------
  #  :section: Edit Action
  # ----------------------------

  def test_edit_turbo_stream
    login("rolf")
    get(:edit, params: { id: "one", locale: "en" },
               format: :turbo_stream)
    assert_response(:success)
    assert_equal("one", assigns(:tag))
    assert_includes(assigns(:edit_tags), "one")
  end

  def test_edit_unofficial_language
    login("mary")
    get(:edit, params: { id: "one", locale: "el" },
               format: :turbo_stream)
    assert_response(:success)
    assert_equal("one", assigns(:tag))
  end

  def test_edit_sets_error_on_auth_failure
    login("zero_user")
    @controller.params = ActionController::Parameters.new(
      id: "one", locale: "en"
    )
    @controller.send(:edit)
    assert(assigns(:msg).present?)
  end

  def test_edit_sets_error_on_bad_locale
    login("rolf")
    @controller.params = ActionController::Parameters.new(
      id: "one", locale: "bad"
    )
    @controller.send(:edit)
    assert(assigns(:msg).present?)
  end

  def test_edit_with_plural_tag
    login("rolf")
    get(:edit, params: { id: "two", locale: "en" },
               format: :turbo_stream)
    assert_response(:success)
    edit_tags = assigns(:edit_tags)
    assert_includes(edit_tags, "two")
    assert_includes(edit_tags, "twos")
    assert_includes(edit_tags, "TWO")
    assert_includes(edit_tags, "TWOS")
  end

  # ----------------------------
  #  :section: Update Action
  # ----------------------------

  def test_update_translation_change
    login("rolf")
    str = translation_strings(:english_one)
    old_text = str.text

    use_test_locales do
      patch(
        :update,
        params: {
          id: "one", locale: "en",
          tag_one: "updated_one"
        },
        format: :turbo_stream
      )
    end
    assert_response(:success)
    str.reload
    assert_equal("updated_one", str.text)
  ensure
    str&.update!(text: old_text)
  end

  def test_update_translation_no_change
    login("rolf")
    str = translation_strings(:english_one)
    old_updated_at = str.updated_at

    patch(
      :update,
      params: {
        id: "one", locale: "en",
        tag_one: str.text
      },
      format: :turbo_stream
    )
    assert_response(:success)
    str.reload
    assert(str.updated_at >= old_updated_at)
  end

  def test_update_creates_new_translation
    login("mary")
    lang = languages(:french)
    tag = "three"
    assert_nil(
      lang.translation_strings.find_by(tag: tag)
    )

    use_test_locales do
      patch(
        :update,
        params: {
          id: tag, locale: "fr",
          "tag_#{tag}": "trois"
        },
        format: :turbo_stream
      )
    end
    assert_response(:success)
    new_str = lang.translation_strings.find_by(tag: tag)
    assert_not_nil(new_str)
    assert_equal("trois", new_str.text)
  ensure
    lang.translation_strings.find_by(tag: tag)&.destroy if lang
  end

  def test_update_error_message_on_auth_failure
    login("zero_user")
    @controller.instance_variable_set(:@user, users(:zero_user))
    @controller.params = ActionController::Parameters.new(
      id: "one", locale: "en", tag_one: "nope"
    )
    assert_raises(RuntimeError) do
      @controller.send(:set_language_and_authorize_user)
    end
  end

  # ----------------------------
  #  :section: Helper Methods
  # ----------------------------

  def test_tags_to_edit_with_blank_tag
    lang = languages(:english)
    strings = lang.localization_strings
    result = @controller.send(:tags_to_edit, nil, strings)
    assert_equal([], result)

    result = @controller.send(:tags_to_edit, "", strings)
    assert_equal([], result)
  end

  def test_tags_to_edit_with_matching_variants
    lang = languages(:english)
    strings = lang.localization_strings
    result = @controller.send(:tags_to_edit, "two", strings)
    assert_includes(result, "two")
    assert_includes(result, "twos")
    assert_includes(result, "TWO")
    assert_includes(result, "TWOS")
  end

  def test_tags_to_edit_with_no_match
    lang = languages(:english)
    strings = lang.localization_strings
    result = @controller.send(
      :tags_to_edit, "nonexistent", strings
    )
    assert_equal(["nonexistent"], result)
  end

  def test_preview_string_short
    lang = languages(:english)
    @controller.instance_variable_set(:@lang, lang)
    result = @controller.send(:preview_string, "hello world")
    assert_equal("hello world", result)
  end

  def test_preview_string_with_newlines
    lang = languages(:english)
    @controller.instance_variable_set(:@lang, lang)
    result = @controller.send(:preview_string, "line1\nline2")
    assert_equal("line1 / line2", result)
  end

  def test_preview_string_truncates_long_strings
    lang = languages(:english)
    @controller.instance_variable_set(:@lang, lang)
    long_str = "a" * 300
    result = @controller.send(:preview_string, long_str, 250)
    assert(result.length < 300)
    assert(result.end_with?("..."))
  end

  def test_error_message_in_test_env
    lang = languages(:english)
    @controller.instance_variable_set(:@lang, lang)
    error = RuntimeError.new("test error")
    result = @controller.send(:error_message, error)
    assert_equal(["test error"], result)
  end

  def test_error_message_without_lang
    @controller.instance_variable_set(:@lang, nil)
    error = RuntimeError.new("no lang error")
    result = @controller.send(:error_message, error)
    assert_equal(["no lang error"], result)
  end

  def test_build_record_maps_official_language
    lang = languages(:english)
    @controller.send(:build_record_maps, lang)
    translated = assigns(:translated_records)
    official = assigns(:official_records)
    assert_equal(translated, official)
    assert(translated.key?("one"))
  end

  def test_build_record_maps_unofficial_language
    lang = languages(:french)
    @controller.send(:build_record_maps, lang)
    translated = assigns(:translated_records)
    official = assigns(:official_records)
    assert_not_equal(translated, official)
    assert(translated.key?("one"))
    assert(official.key?("one"))
  end

  def test_secondary_tag
    @controller.instance_variable_set(:@tags_used, {
                                        "two" => true
                                      })
    assert(@controller.send(:secondary_tag?, "twos"))
    assert(@controller.send(:secondary_tag?, "Two"))
    assert_not(@controller.send(:secondary_tag?, "one"))
  end

  def test_include_unlisted_tags
    lang = languages(:english)
    file = mock_template
    # "unknown_tag" is not in the template file
    tags = hashify("unknown_tag")
    form = @controller.build_index(lang, tags, file)
    major_headers = form.select do |item|
      item.is_a?(
        TranslationsController::TranslationsUIMajorHeader
      )
    end
    unlisted_header = major_headers.find do |h|
      h.string.include?("UNLISTED")
    end
    assert_not_nil(unlisted_header)
    tag_fields = form.select do |item|
      item.is_a?(
        TranslationsController::TranslationsUITagField
      )
    end
    assert(tag_fields.any? { |tf| tf.ttag == "unknown_tag" })
  end

  def test_tags_used_on_page_with_valid_page
    Language.track_usage
    :name.l
    :user.l
    page = Language.save_tags
    result = @controller.send(:tags_used_on_page, page)
    assert_not_nil(result)
    assert_includes(result, "name")
    assert_includes(result, "user")
  end

  def test_tags_used_on_page_with_expired_page
    result = @controller.send(:tags_used_on_page, "xxx")
    assert_nil(result)
  end

  def test_tags_used_on_page_with_blank
    result = @controller.send(:tags_used_on_page, nil)
    assert_nil(result)

    result = @controller.send(:tags_used_on_page, "")
    assert_nil(result)
  end

  def test_translations_ui_string_classes
    major = TranslationsController::TranslationsUIMajorHeader.new(
      "line1", "line2"
    )
    assert_equal("line1\nline2", major.string)
    assert_equal("line1\nline2", major.to_s)

    minor = TranslationsController::TranslationsUIMinorHeader.new(
      "header"
    )
    assert_equal("header", minor.string)

    comment = TranslationsController::TranslationsUIComment.new(
      "a comment"
    )
    assert_equal("a comment", comment.string)

    tag_field = TranslationsController::TranslationsUITagField.new(
      "my_tag"
    )
    assert_equal("my_tag", tag_field.ttag)
    assert_equal("my_tag", tag_field.string)
  end

  def test_validate_language_and_user_bad_locale
    @controller.instance_variable_set(:@user, users(:rolf))
    assert_raises(RuntimeError) do
      @controller.send(
        :validate_language_and_user, "bad", nil
      )
    end
  end

  def test_validate_language_and_user_no_user
    @controller.instance_variable_set(:@user, nil)
    lang = languages(:english)
    assert_raises(RuntimeError) do
      @controller.send(
        :validate_language_and_user, "en", lang
      )
    end
  end

  def test_validate_language_and_user_not_successful
    @controller.instance_variable_set(
      :@user, users(:zero_user)
    )
    lang = languages(:english)
    assert_raises(RuntimeError) do
      @controller.send(
        :validate_language_and_user, "en", lang
      )
    end
  end

  def test_validate_language_and_user_reviewer_required
    @controller.instance_variable_set(:@user, users(:mary))
    lang = languages(:english)
    assert_raises(RuntimeError) do
      @controller.send(
        :validate_language_and_user, "en", lang
      )
    end
  end

  def test_validate_language_and_user_success
    @controller.instance_variable_set(:@user, users(:rolf))
    lang = languages(:english)
    assert_nothing_raised do
      @controller.send(
        :validate_language_and_user, "en", lang
      )
    end
  end

  def test_set_language_and_authorize_user_default_locale
    login("rolf")
    @controller.instance_variable_set(:@user, users(:rolf))
    @controller.params = ActionController::Parameters.new(
      locale: nil
    )
    lang = @controller.send(
      :set_language_and_authorize_user
    )
    assert_equal(I18n.locale.to_s, lang.locale)
  end
end
