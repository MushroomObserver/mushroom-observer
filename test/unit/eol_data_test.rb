# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class EolDataTest < UnitTestCase
  def test_create
    obj = EolData.new
    assert_equal(SortedSet, obj.names.class)
    assert_equal(2, obj.name_count)
    assert_equal(2, obj.total_image_count)
    assert_equal(1, obj.total_description_count)
    assert_equal(Array, obj.all_images.class)
    assert_equal(Array, obj.all_descriptions.class)

    name_test(obj, names(:fungi))
    name_id = name_test(obj, names(:peltigera))
    
    assert(obj.has_descriptions?(name_id))
    assert_equal(Array, obj.descriptions(name_id).class)
    assert(1 <= obj.description_count(name_id))
    description = obj.descriptions(name_id)[0]
    assert_equal(description.user.legal_name, obj.authors(description.id))
    
    license = licenses(:ccnc30)
    assert_equal(license.url, obj.license_url(license.id))
  end
  
  def name_test(obj, name)
    name_id = name.id
    assert(obj.has_images?(name_id))
    assert_equal(Array, obj.images(name_id).class)
    assert(1 <= obj.image_count(name_id))
    assert_equal(name.user.legal_name, obj.legal_name(name.user.id))
    assert_equal(name.real_search_name, obj.image_to_names(obj.images(name_id)[0].id))
    name_id
  end
end
