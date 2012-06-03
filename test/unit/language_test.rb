# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class LanguageTest < UnitTestCase

  def test_official
    english = languages(:english)
    all_but_english = Language.all - [english]
    assert_objs_equal(english, Language.official)
    assert_obj_list_equal(all_but_english, Language.unofficial)
  end
  
  def test_top_contributors
    english = languages(:english)
    french = languages(:french)
    greek = languages(:greek)
    assert_equal([], english.top_contributors)
    assert_equal([[2, 'mary'], [1, 'rolf']], french.top_contributors)
    assert_equal([[2, 'mary']], french.top_contributors(1))
    assert_equal([[4, 'dick']], greek.top_contributors)
  end

  def test_update_localization
    str = translation_strings(:english_one)
    str.text = 'shazam'
    str.update_localization
    assert_equal('shazam', :one.l)

    str = translation_strings(:french_one)
    str.text = 'la chazame'
    assert_raises(RuntimeError) { str.update_localization }
    Locale.code = str.language.locale
    str.update_localization
    assert_equal('la chazame', :one.l)
  end
end
