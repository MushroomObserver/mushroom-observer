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
    str.update_localization
    assert_equal('shazam', :one.l)
    Locale.code = str.language.locale
    assert_equal('la chazame', :one.l)
  end

  def test_versioning
    time1 = 1.year.ago
    time2 = time1 + 1.minute
    time3 = time2 + 1.hour
    time4 = time3 + 1.week

    User.current = @katrina
    lang = languages(:english)
    lang.translation_strings.create(
      :tag  => 'frobozz',
      :text => 'wizard',
      :modified => time1
    )
    str = TranslationString.last
    assert_equal('frobozz', str.tag)
    assert_equal('wizard', str.text)
    assert_equal(@katrina.id, str.user_id)
    assert_in_delta(time1, str.modified, 1.second)
    assert_equal(1, str.version)

    # Combine with last version if same user changes it within a day.
    str.update_attributes(
      :text => 'Wizard of Zork',
      :modified => time2
    )
    str = TranslationString.last
    assert_equal(1, str.version)
    latest = str.versions.latest
    assert_equal('Wizard of Zork', latest.text)
    assert_equal(@katrina.id, latest.user_id)
    assert_in_delta(time2, latest.modified, 1.second)

    # Make new version for new user, regardless of time since last change.
    User.current = @rolf
    str.update_attributes(
      :text => 'Wizard of Zork II',
      :modified => time3
    )
    str = TranslationString.last
    assert_equal(2, str.version)
    latest = str.versions.latest
    assert_equal('Wizard of Zork II', latest.text)
    assert_equal(@rolf.id, latest.user_id)
    assert_in_delta(time3, latest.modified, 1.second)

    # Make new version after a day, regardless who changes it.
    str.update_attributes(
      :text => 'Magic Cave Company',
      :modified => time4
    )
    str = TranslationString.last
    assert_equal(3, str.version)
    latest = str.versions.latest
    assert_equal('Magic Cave Company', latest.text)
    assert_equal(@rolf.id, latest.user_id)
    assert_in_delta(time4, latest.modified, 1.second)
  end

  def test_update_recent_translations
    one = translation_strings(:english_one)
    old_val = one.tag.to_sym.l
    one.update_attributes(
      :text => 'new_val',
      :modified => 1.hour.ago
    )
    Language.last_update = 1.minute.ago
    Language.update_recent_translations
    assert_equal(old_val, one.tag.to_sym.l)
    Language.last_update = 1.day.ago
    Language.update_recent_translations
    assert_equal('new_val', one.tag.to_sym.l)
  end
end
