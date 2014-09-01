# encoding: utf-8

require 'test_helper'

# require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SpecimenTest < UnitTestCase
  def test_fields
    assert(specimens(:interesting_unknown).observations.length > 0)
    assert(specimens(:interesting_unknown).herbarium)
    assert(specimens(:interesting_unknown).herbarium_label)
    assert(specimens(:interesting_unknown).when)
    assert(specimens(:interesting_unknown).notes)
  end
end
