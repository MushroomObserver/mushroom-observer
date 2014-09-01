# encoding: utf-8
require 'test_helper'

class SymbolExtensionsTest < UnitTestCase
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
    assert_equal 'This has &#8220;quotes&#8221;', :quote_test.t
  end
  
  def test_quote_birds
    assert_equal 'This has &#8220;Birds&#8221;', :quote_them.t(them: "birds")
  end

  def test_Yep
    assert_equal 'Yes', :YEP.t
  end
  
  def test_yep
    assert_equal 'yes', :yep.t
  end
  
  def test_Nope
    assert_equal 'No', :NOPE.t
  end
  
  def test_nope
    assert_equal 'no', :nope.t
  end
  
  def test_with_newlines
    assert_equal "This<br />\nhas<br />\nnewlines", :with_newlines.t
  end
  
  def test_with_a_link
    assert_equal "<a href=\"http://mushroomobserver.org\">See this link</a>", :with_a_link.t
  end

  def test_hello_has_translation
    assert :hello.has_translation?
  end

  def test_Hello_has_translation
    assert :Hello.has_translation?
  end

  def test_no_translation
    assert !:no_translation.has_translation?
  end
end
