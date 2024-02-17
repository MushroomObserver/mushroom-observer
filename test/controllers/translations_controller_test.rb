# frozen_string_literal: true

require("test_helper")

class TranslationsControllerTest < FunctionalTestCase
  # Only tests the index. :edit and :update only respond to js
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
end
