# encoding: utf-8

require "test_helper"

class HerbariumTest < UnitTestCase
  def test_specimens
    assert(herbaria(:nybg_herbarium).specimens.length > 1)
  end

  def test_mailing_address
    assert(herbaria(:nybg_herbarium).mailing_address)
    assert_nil(herbaria(:rolf_herbarium).mailing_address)
  end

  def test_location
    assert(herbaria(:nybg_herbarium).location)
    assert_nil(herbaria(:rolf_herbarium).location)
  end

  def test_email
    assert(herbaria(:nybg_herbarium).email)
    assert(herbaria(:rolf_herbarium).email)
  end

  def test_curators
    assert(herbaria(:nybg_herbarium).curators.length > 1)
    assert_equal(1, herbaria(:rolf_herbarium).curators.length)
  end

  def test_fields
    assert(herbaria(:nybg_herbarium).name)
    assert(herbaria(:nybg_herbarium).description)
    assert(herbaria(:nybg_herbarium).code)
  end
end
