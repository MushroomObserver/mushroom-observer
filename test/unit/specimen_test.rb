# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SpecimenTest < UnitTestCase
  def test_fields
    assert(specimens(:detailed_unknown).observations.length > 0)
    assert(specimens(:detailed_unknown).herbarium)
    assert(specimens(:detailed_unknown).herbarium_label)
    assert(specimens(:detailed_unknown).when)
    assert(specimens(:detailed_unknown).notes)
  end
end
