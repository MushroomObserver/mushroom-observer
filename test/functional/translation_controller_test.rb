# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class TranslationControllerTest < FunctionalTestCase

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
      "# observer/index\n",
      "index_title: Main Index\n",
      "# you don't see this every day\n",
      "index_error: An unusual error occurred\n",
      "index_help: >\n",
      "  This page shows an index of objects.\n",
      "\n",
      "index_prefs: Your Account\n",
      "\n",
      "# account/prefs\n",
      "prefs_title: Your Account\n",
      "\n",
    ].join
  end

  def hashify(*args)
    hash = {}
    for arg in args
      hash[arg] = true
    end
    return hash
  end

  def assert_major_header(str, item)
    assert(item.is_a? TranslationController::TranslationFormMajorHeader)
    assert_equal(str, item.string)
  end

  def assert_minor_header(str, item)
    assert(item.is_a? TranslationController::TranslationFormMinorHeader)
    assert_equal(str, item.string)
  end

  def assert_comment(str, item)
    assert(item.is_a? TranslationController::TranslationFormComment)
    assert_equal(str, item.string)
  end

  def assert_tag_field(tag, item)
    assert(item.is_a? TranslationController::TranslationFormTagField)
    assert_equal(tag, item.tag)
  end

################################################################################

  def test_edit_translations_with_page
    Language.track_usage
    :name.l
    assert_equal(['name'], Language.tags_used)
    page = Language.save_tags
    get(:edit_translations, :page => page)
  end

  def test_primary_tag
    lang = languages(:english)
    strings = lang.localization_strings
    assert(strings.length >= 8)
    assert_equal('one', @controller.primary_tag('one', strings))
    assert_equal('two', @controller.primary_tag('two', strings))
    assert_equal('two', @controller.primary_tag('Two', strings))
    assert_equal('two', @controller.primary_tag('TWOS', strings))
    assert_equal('two', @controller.primary_tag('tWoS', strings))
    assert_equal('four', @controller.primary_tag('FoUr', strings))
  end

  def test_build_form
    lang = languages(:english)
    file = mock_template

    form = @controller.build_form(lang, hashify(), file)
    assert_equal([], form)

    form = @controller.build_form(lang, hashify('name'), file)
    assert_major_header('IMPORTANT STUFF', form.shift)
    assert_minor_header('Main Objects:', form.shift)
    assert_tag_field('name', form.shift)
    assert(form.empty?)

    form = @controller.build_form(lang, hashify('index', 'index_help'), file)
    assert_major_header('IMPORTANT STUFF', form.shift)
    assert_minor_header('Actions:', form.shift)
    assert_tag_field('index', form.shift)
    assert_major_header('MAIN PAGES', form.shift)
    assert_minor_header('observer/index', form.shift)
    assert_tag_field('index_title', form.shift)
    assert_comment('you don\'t see this every day', form.shift)
    assert_tag_field('index_error', form.shift)
    assert_tag_field('index_help', form.shift)
    assert_tag_field('index_prefs', form.shift)
    assert(form.empty?)
  end

  def test_authorization
    get(:edit_translations, :locale => 'en-US')
    assert_flash_error
    assert_response(:redirect)

    get(:edit_translations, :locale => 'el-GR')
    assert_flash_error
    assert_response(:redirect)

    login('mary')
    get(:edit_translations, :locale => 'en-US')
    assert_flash_error
    assert_response(:redirect)

    get(:edit_translations, :locale => 'el-GR')
    assert_no_flash
    assert_response(:success)

    login('rolf')
    get(:edit_translations, :locale => 'en-US')
    assert_no_flash
    assert_response(:success)
  end

  def test_edit_translation_form
    old_one = :one.l

    login('rolf')
    get(:edit_translations)
    assert_no_flash
    assert_response(:success, :locale => 'en-US')
    assert_select("input[type=submit][value=#{:SAVE.l}]", 0)

    get(:edit_translations, :locale => 'en-US', :tag => 'xxx')
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_select("textarea[name=tag_xxx]", 1)
    assert_textarea_value(:tag_xxx, '')

    get_with_dump(:edit_translations, :locale => 'en-US', :tag => 'two')
    assert_no_flash
    assert_response(:success)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_select("textarea[name=tag_two]", 1)
    assert_select("textarea[name=tag_twos]", 1)
    assert_select("textarea[name=tag_TWO]", 1)
    assert_select("textarea[name=tag_TWOS]", 1)
    assert_textarea_value(:tag_two, 'two')
    assert_textarea_value(:tag_twos, 'twos')
    assert_textarea_value(:tag_TWO, 'Two')
    assert_textarea_value(:tag_TWOS, 'Twos')

    assert_equal(old_one, :one.l)
    post(:edit_translations,
      :locale => 'en-US',
      :tag => 'one',
      :tag_one => 'uno',
      :commit => :SAVE.l
    )
    assert_flash_success
    assert_equal('uno', :one.l)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_select("textarea[name=tag_one]", 1)
    assert_textarea_value(:tag_one, 'uno')

    post(:edit_translations,
      :locale => 'en-US',
      :tag => 'one',
      :tag_one => 'ichi',
      :commit => :CANCEL.l
    )
    assert_no_flash
    assert_equal('uno', :one.l)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 0)

    post(:edit_translations,
      :locale => 'el-GR',
      :tag => 'one',
      :tag_one => 'ichi',
      :commit => :RELOAD.l
    )
    assert_no_flash
    assert_equal('uno', :one.l)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_textarea_value(:tag_one, 'ένα')

    post(:edit_translations,
      :locale => 'el-GR',
      :tag => 'one',
      :tag_one => 'ichi',
      :commit => :SAVE.l
    )
    assert_flash_success
    assert_equal('uno', :one.l)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_textarea_value(:tag_one, 'ichi')
    I18n.locale = 'el-GR'
    assert_equal('ichi', :one.l)
  end

  def test_edit_translation_ajax_form
    old_one = :one.l

    login('rolf')
    get(:edit_translations_ajax_get, :locale => 'en-US', :tag => 'two')
    assert_no_flash
    assert_response(:success)
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_select("textarea[name=tag_two]", 1)
    assert_select("textarea[name=tag_twos]", 1)
    assert_select("textarea[name=tag_TWO]", 1)
    assert_select("textarea[name=tag_TWOS]", 1)
    assert_textarea_value(:tag_two, 'two')
    assert_textarea_value(:tag_twos, 'twos')
    assert_textarea_value(:tag_TWO, 'Two')
    assert_textarea_value(:tag_TWOS, 'Twos')

    assert_equal(old_one, :one.l)
    post(:edit_translations_ajax_post,
      :locale => 'en-US',
      :tag => 'one',
      :tag_one => 'uno',
      :commit => :SAVE.l
    )
    assert_no_flash
    assert_match(/locale = "en-US"/, @response.body)
    assert_match(/tag = "one"/, @response.body)
    assert_match(/str = "uno"/, @response.body)
    assert_equal('uno', :one.l)

    get(:edit_translations_ajax_get, :locale => 'en-US', :tag => 'one')
    assert_no_flash
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_select("textarea[name=tag_one]", 1)
    assert_textarea_value(:tag_one, 'uno')

    post(:edit_translations_ajax_post,
      :locale => 'el-GR',
      :tag => 'one',
      :tag_one => 'ichi',
      :commit => :SAVE.l
    )
    assert_no_flash
    assert_match(/locale = "el-GR"/, @response.body)
    assert_match(/tag = "one"/, @response.body)
    assert_match(/str = "ichi"/, @response.body)
    assert_equal('uno', :one.l)

    get(:edit_translations_ajax_get, :locale => 'el-GR', :tag => 'one')
    assert_no_flash
    assert_select("input[type=submit][value=#{:SAVE.l}]", 1)
    assert_textarea_value(:tag_one, 'ichi')

    I18n.locale = 'el-GR'
    assert_equal('ichi', :one.l)
  end

  def test_page_expired
    login('rolf')
    make_admin

    Language.track_usage
    :one.l
    :two.l
    page = Language.save_tags

    # Page is good, should only display the two tags used above.
    get(:edit_translations, :locale => 'en-US', :page => page)
    assert_no_flash
    assert_equal(2, assigns(:show_tags).length)

    # Simulate page expiration: result is it will display all tags, not just the two used above.
    get(:edit_translations, :locale => 'en-US', :page => 'xxx')
    assert_flash_error
    assert(assigns(:show_tags).length > 2)
  end
end
