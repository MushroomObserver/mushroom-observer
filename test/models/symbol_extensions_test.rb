# frozen_string_literal: true

require "test_helper"

class SymbolExtensionsTest < UnitTestCase
  def test_localize_postprocessing
    Symbol.raise_errors
    assert_equal("",             Symbol.test_localize(""))
    assert_equal("blah",         Symbol.test_localize("blah"))
    assert_equal("one\n\ntwo",   Symbol.test_localize('one\n\ntwo'))
    assert_equal("bob",          Symbol.test_localize("[user]", user: "bob"))
    assert_equal(
      "bob and fred",
      Symbol.test_localize("[bob] and [fred]", bob: "bob", fred: "fred")
    )
    assert_equal("user",
                 Symbol.test_localize("[:user]"))
    assert_equal("Show Name",
                 Symbol.test_localize("[:show_object(type=:name)]"))
    assert_equal("Show Str",
                 Symbol.test_localize("[:show_object(type='str')]"))
    assert_equal("Show Str",
                 Symbol.test_localize('[:show_object(type="str")]'))
    assert_equal("Show 1",
                 Symbol.test_localize("[:show_object(type=1)]"))
    assert_equal("Show 12.34",
                 Symbol.test_localize("[:show_object(type=12.34)]"))
    assert_equal("Show -0.23",
                 Symbol.test_localize("[:show_object(type=-0.23)]"))
    assert_equal("Show Xxx",
                 Symbol.test_localize("[:show_object(type=id)]", id: "xxx"))
    assert_equal("Show Image",
                 Symbol.test_localize("[:show_object(type=id)]", id: :image))
    assert_equal(
      "Show < ! >",
      Symbol.test_localize('[:show_object(type="< ! >",blah="ignore")]')
    )

    # Test capitalization and number.
    assert_equal("name", :name.l)
    assert_equal("Name", :Name.l)
    assert_equal("Name", :NAME.l)
    assert_equal("species list", :species_list.l)
    assert_equal("Species list", :Species_list.l)
    assert_equal("Species List", :SPECIES_LIST.l)
    assert_equal("species list",
                 Symbol.test_localize("[type]", type: :species_list))
    assert_equal("Species list",
                 Symbol.test_localize("[Type]", type: :species_list))
    assert_equal("Species list",
                 Symbol.test_localize("[tYpE]", type: :species_list))
    assert_equal("Species List",
                 Symbol.test_localize("[TYPE]", type: :species_list))
    assert_equal("species list", Symbol.test_localize("[:species_list]"))
    assert_equal("Species list", Symbol.test_localize("[:Species_list]"))
    assert_equal("Species list", Symbol.test_localize("[:sPeCiEs_lIsT]"))
    assert_equal("Species List", Symbol.test_localize("[:SPECIES_LIST]"))
  end

  def test_hello
    assert_equal "Hello world", :hello.t
  end

  def test_the_birds_flew_by
    assert_equal "The birds flew by", :they_flew_by.t(they: "birds")
  end

  def test_birds_fly
    assert_equal "Birds fly", :they_fly.t(they: "birds")
  end

  def test_quotes
    assert_equal("This has &#8220;quotes&#8221;", :quote_test.t)
  end

  def test_quote_birds
    assert_equal("This has &#8220;Birds&#8221;", :quote_them.t(them: "birds"))
  end

  def test_Yep # rubocop:disable Naming/MethodName
    assert_equal "Yes", :YEP.t
  end

  def test_yep
    assert_equal "yes", :yep.t
  end

  def test_Nope # rubocop:disable Naming/MethodName
    assert_equal "No", :NOPE.t
  end

  def test_nope
    assert_equal "no", :nope.t
  end

  def test_with_newlines
    assert_equal "This<br />\nhas<br />\nnewlines", :with_newlines.t
  end

  def test_with_a_link
    assert_equal("<a href=\"http://mushroomobserver.org\">See this link</a>",
                 :with_a_link.t)
  end

  def test_hello_has_translation
    assert :hello.has_translation?
  end

  def test_Hello_has_translation # rubocop:disable Naming/MethodName
    assert :Hello.has_translation?
  end

  def test_no_translation
    assert_not :no_translation.has_translation?
  end

  def test_upcase_first
    assert_equal(:A, :a.upcase_first)
    assert_equal(:AB, :aB.upcase_first)
    assert_equal(:Abc, :abc.upcase_first)
  end
end
