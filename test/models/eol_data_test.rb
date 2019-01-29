require "test_helper"

class EolDataTest < UnitTestCase
  def name_test(obj, name)
    name_id = name.id
    assert(obj.has_images?(name_id))
    assert_equal(Array, obj.images(name_id).class)
    assert(obj.image_count(name_id).positive?,
           "Expected #{name.text_name} image count > 0; " \
           "got #{obj.image_count(name_id)}")
    assert_equal(name.user.legal_name, obj.legal_name(name.user.id))
    assert_equal(name.real_search_name,
                 obj.image_to_names(obj.images(name_id)[0].id))
  end

  def test_create
    obj = EolData.new

    assert_equal(SortedSet, obj.names.class)
    assert(obj.name_count >= 2)
    assert(obj.total_image_count >= 2)
    assert(obj.total_description_count >= 1)
    assert_equal(Array, obj.all_images.class)
    assert_equal(Array, obj.all_descriptions.class)

    name_test(obj, names(:fungi))
    name_test(obj, names(:peltigera))

    name_id = names(:peltigera).id
    assert(obj.has_descriptions?(name_id))
    assert_equal(Array, obj.descriptions(name_id).class)
    assert(obj.description_count(name_id) >= 1)
    description = obj.descriptions(name_id)[0]
    assert_equal(description.user.legal_name, obj.authors(description.id))

    license = licenses(:ccnc30)
    assert_equal(license.url, obj.license_url(license.id))
  end

  def test_glossary_term_query
    obj = EolData.new
    name_count = obj.name_count
    Name.connection.delete("DELETE FROM glossary_terms_images")
    obj = EolData.new
    assert_equal(name_count, obj.name_count)
  end

  def test_refresh_links_to_eol
    initial_count = Triple.count
    obj = EolData.new
    obj.refresh_links_to_eol
    assert(initial_count < Triple.count)
  end
end
