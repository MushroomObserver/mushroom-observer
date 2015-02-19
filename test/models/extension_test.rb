# encoding: utf-8
require 'test_helper'

class ExtensionTest < UnitTestCase

  # ----------------------------
  #  :section: Symbol Tests
  # ----------------------------

  def test_localize_postprocessing
    Symbol.raise_errors
    assert_equal('',             Symbol.test_localize(''))
    assert_equal('blah',         Symbol.test_localize('blah'))
    assert_equal("one\n\ntwo",   Symbol.test_localize('one\n\ntwo'))
    assert_equal('bob',          Symbol.test_localize('[user]', :user => 'bob'))
    assert_equal('bob and fred', Symbol.test_localize('[bob] and [fred]', :bob => 'bob', :fred => 'fred'))
    assert_equal('user',         Symbol.test_localize('[:user]'))
    assert_equal('Show Name',    Symbol.test_localize('[:show_object(type=:name)]'))
    assert_equal('Show Str',     Symbol.test_localize("[:show_object(type='str')]"))
    assert_equal('Show Str',     Symbol.test_localize('[:show_object(type="str")]'))
    assert_equal('Show 1',       Symbol.test_localize('[:show_object(type=1)]'))
    assert_equal('Show 12.34',   Symbol.test_localize('[:show_object(type=12.34)]'))
    assert_equal('Show -0.23',   Symbol.test_localize('[:show_object(type=-0.23)]'))
    assert_equal('Show Xxx',     Symbol.test_localize('[:show_object(type=id)]', :id => 'xxx'))
    assert_equal('Show Image',   Symbol.test_localize('[:show_object(type=id)]', :id => :image))
    assert_equal('Show < ! >',   Symbol.test_localize('[:show_object(type="< ! >",blah="ignore")]'))

    # Test capitalization and number.
    assert_equal('name', :name.l)
    assert_equal('Name', :Name.l)
    assert_equal('Name', :NAME.l)
    assert_equal('species list', :species_list.l)
    assert_equal('Species list', :Species_list.l)
    assert_equal('Species List', :SPECIES_LIST.l)
    assert_equal('species list', Symbol.test_localize('[type]', :type => :species_list))
    assert_equal('Species list', Symbol.test_localize('[Type]', :type => :species_list))
    assert_equal('Species list', Symbol.test_localize('[tYpE]', :type => :species_list))
    assert_equal('Species List', Symbol.test_localize('[TYPE]', :type => :species_list))
    assert_equal('species list', Symbol.test_localize('[:species_list]'))
    assert_equal('Species list', Symbol.test_localize('[:Species_list]'))
    assert_equal('Species list', Symbol.test_localize('[:sPeCiEs_lIsT]'))
    assert_equal('Species List', Symbol.test_localize('[:SPECIES_LIST]'))
  end

  # ----------------------------
  #  :section: String Tests
  # ----------------------------

  def test_string_truncate_html
    assert_equal('123', '123'.truncate_html(5))
    assert_equal('12345', '12345'.truncate_html(5))
    assert_equal('1234...', '123456'.truncate_html(5))
    assert_equal('<i>1234...</i>', '<i>123456</i>'.truncate_html(5))
    assert_equal('<i>12<b>3</b>4...</i>', '<i>12<b>3</b>456</i>'.truncate_html(5))
    assert_equal('<i>12<b>3<hr/></b>4...</i>', '<i>12<b>3<hr/></b>456</i>'.truncate_html(5))
    assert_equal('<i>12</i>3<b>4...</b>', '<i>12</i>3<b>456</b>'.truncate_html(5))
  end

  def test_iconv
    assert_equal('áëìøũ', 'áëìøũ'.iconv('utf-8').encode('utf-8'))
    assert_equal('áëìøu', 'áëìøũ'.iconv('iso8859-1').encode('utf-8'))
    assert_equal('aeiou', 'áëìøũ'.iconv('ascii-8bit').encode('utf-8'))
    assert_equal('ενα', 'ενα'.iconv('utf-8').encode('utf-8'))
    assert_equal('???', 'ενα'.iconv('ascii-8bit').encode('utf-8'))
  end

  # ----------------------------
  #  :section: Hash Tests
  # ----------------------------

  def test_flatten
    assert_equal( {a: 1, b: 2, c: 3},
                  {a: 1, bb: {b: 2, cc: {c: 3}}}.flatten )
  end

  def test_remove_nils
    hash = {a: 1, b: nil, c: 3, d: nil}
    hash.remove_nils!
    assert_equal({a: 1, c: 3}, hash)
  end

  # ----------------------------
  #  :section: Time Tests
  # ----------------------------

  def test_fancy_time
    assert_fancy_time(0.seconds, :time_just_seconds_ago)
    assert_fancy_time(59.seconds, :time_just_seconds_ago)
    assert_fancy_time(60.seconds, :time_one_minute_ago)
    assert_fancy_time(119.seconds, :time_one_minute_ago)
    assert_fancy_time(120.seconds, :time_minutes_ago, :n => 2)
    assert_fancy_time(59.minutes, :time_minutes_ago, :n => 59)
    assert_fancy_time(60.minutes, :time_one_hour_ago)
    assert_fancy_time(119.minutes, :time_one_hour_ago)
    assert_fancy_time(120.minutes, :time_hours_ago, :n => 2)
    assert_fancy_time(23.hours, :time_hours_ago, :n => 23)
    assert_fancy_time(24.hours, :time_one_day_ago)
  end

  def assert_fancy_time(diff, tag, args={})
    ref = Time.now
    time = ref - diff
    expect = tag.l(args.merge(:date => time.web_date))
    actual = time.fancy_time(ref)
    assert_equal(expect, actual)
  end
end
