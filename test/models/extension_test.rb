# encoding: utf-8
require "test_helper"

class ExtensionTest < UnitTestCase
  # ----------------------------
  #  :section: Symbol Tests
  # ----------------------------

  def test_localize_postprocessing
    Symbol.raise_errors
    assert_equal("",             Symbol.test_localize(""))
    assert_equal("blah",         Symbol.test_localize("blah"))
    assert_equal("one\n\ntwo",   Symbol.test_localize('one\n\ntwo'))
    assert_equal("bob",          Symbol.test_localize("[user]", user: "bob"))
    assert_equal("bob and fred", Symbol.test_localize("[bob] and [fred]", bob: "bob", fred: "fred"))
    assert_equal("user",         Symbol.test_localize("[:user]"))
    assert_equal("Show Name",    Symbol.test_localize("[:show_object(type=:name)]"))
    assert_equal("Show Str",     Symbol.test_localize("[:show_object(type='str')]"))
    assert_equal("Show Str",     Symbol.test_localize('[:show_object(type="str")]'))
    assert_equal("Show 1",       Symbol.test_localize("[:show_object(type=1)]"))
    assert_equal("Show 12.34",   Symbol.test_localize("[:show_object(type=12.34)]"))
    assert_equal("Show -0.23",   Symbol.test_localize("[:show_object(type=-0.23)]"))
    assert_equal("Show Xxx",     Symbol.test_localize("[:show_object(type=id)]", id: "xxx"))
    assert_equal("Show Image",   Symbol.test_localize("[:show_object(type=id)]", id: :image))
    assert_equal("Show < ! >",   Symbol.test_localize('[:show_object(type="< ! >",blah="ignore")]'))

    # Test capitalization and number.
    assert_equal("name", :name.l)
    assert_equal("Name", :Name.l)
    assert_equal("Name", :NAME.l)
    assert_equal("species list", :species_list.l)
    assert_equal("Species list", :Species_list.l)
    assert_equal("Species List", :SPECIES_LIST.l)
    assert_equal("species list", Symbol.test_localize("[type]", type: :species_list))
    assert_equal("Species list", Symbol.test_localize("[Type]", type: :species_list))
    assert_equal("Species list", Symbol.test_localize("[tYpE]", type: :species_list))
    assert_equal("Species List", Symbol.test_localize("[TYPE]", type: :species_list))
    assert_equal("species list", Symbol.test_localize("[:species_list]"))
    assert_equal("Species list", Symbol.test_localize("[:Species_list]"))
    assert_equal("Species list", Symbol.test_localize("[:sPeCiEs_lIsT]"))
    assert_equal("Species List", Symbol.test_localize("[:SPECIES_LIST]"))
  end

  # ----------------------------
  #  :section: Hash Tests
  # ----------------------------

  def test_flatten
    assert_equal({ a: 1, b: 2, c: 3 },
                 { a: 1, bb: { b: 2, cc: { c: 3 } } }.flatten)
  end

  def test_remove_nils
    hash = { a: 1, b: nil, c: 3, d: nil }
    hash.remove_nils!
    assert_equal({ a: 1, c: 3 }, hash)
  end
end
