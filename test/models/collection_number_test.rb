require "test_helper"

class CollectionNumberTest < UnitTestCase
  def test_fields
    num = collection_numbers(:coprinus_comatus_coll_num)
    assert_not(num.observations.empty?)
    assert(num.name)
    assert(num.number)
  end
end
