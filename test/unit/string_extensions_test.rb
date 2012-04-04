# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class StringExtensionsTest < UnitTestCase

  def test_binary_length
    str = 'abčde';
    assert_equal(5, str.length)
    assert_equal(6, str.binary_length)
    assert_equal('abčd', str.truncate_binary_length(5))
    assert_equal('abč', str.truncate_binary_length(4))
    assert_equal('ab', str.truncate_binary_length(3))
    assert_equal('ab', str.truncate_binary_length(2))
    assert_equal('a', str.truncate_binary_length(1))
    assert_equal('', str.truncate_binary_length(0))
  end
end
