# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class EolDataTest < UnitTestCase
  def test_create
    obj = EolData.new
    assert_equal(SortedSet, obj.names.class)
    assert_equal(1, obj.name_count)
    assert_equal(1, obj.total_image_count)
    assert_equal(1, obj.total_description_count)
    name = names(:peltigera)
    name_id = name.id
    assert(obj.has_images?(name_id))
    assert_equal(Array, obj.all_images.class)
    assert_equal(Array, obj.images(name_id).class)
    assert_equal(1, obj.image_count(name_id))
    assert_equal(Array, obj.all_descriptions.class)
    assert(obj.has_descriptions?(name_id))
    assert_equal(Array, obj.descriptions(name_id).class)
    assert_equal(1, obj.description_count(name_id))
    license = licenses(:ccnc30)
    assert_equal(license.url, obj.license_url(license.id))
    assert_equal(name.user.legal_name, obj.legal_name(name.user.id))
    description = obj.descriptions(name_id)[0]
    assert_equal(description.user.legal_name, obj.authors(description.id))
  end
end
