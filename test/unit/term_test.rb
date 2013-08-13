require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class TermTest < UnitTestCase
  def test_term_load
    term = terms(:conic_term)
    assert(term)
  end
end
