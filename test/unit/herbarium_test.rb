# encoding: utf-8

require 'test_helper'

class HerbariumTest < ActiveSupport::TestCase
  def test_specimens
    assert(herbaria(:nybg).specimens.length > 1)
  end

  def test_mailing_address
    assert(herbaria(:nybg).mailing_address)
    assert_nil(herbaria(:rolf).mailing_address)
  end

  def test_location
    assert(herbaria(:nybg).location)
    assert_nil(herbaria(:rolf).location)
  end

  def test_email
    assert(herbaria(:nybg).email)
    assert(herbaria(:rolf).email)
  end

  def test_curators
    assert(herbaria(:nybg).curators.length > 1)
    assert_equal(1, herbaria(:rolf).curators.length)
  end
  
  def test_fields
    assert(herbaria(:nybg).name)
    assert(herbaria(:nybg).description)
    assert(herbaria(:nybg).code)
  end
end
