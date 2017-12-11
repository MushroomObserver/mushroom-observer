require "test_helper"
# Test cached columns in names and observations table.
class CacheTest < UnitTestCase
  # Prove that changing a location name will update observations.where for
  # all the attached observations without changing the updated_at field.
  def test_changing_location_name
    loc = locations(:burbank)
    assert_not_empty(loc.observations)
    first_updated_at = loc.observations.first.updated_at
    loc.update_attributes(name: "Truman, California, USA")
    assert(loc.observations.all? { |o| o.where == loc.name })
    assert_equal(first_updated_at, loc.observations.first.updated_at)
  end

  # Prove that changing a name's lifeform will update observations.lifeform for
  # all the attached observations without changing the updated_at field.
  def test_changing_lifeform
    name = names(:stereum_hirsutum)
    assert_not_empty(name.observations)
    first_updated_at = name.observations.first.updated_at
    name.update_attributes(lifeform: " lichen ")
    assert(name.observations.all? { |o| o.lifeform == name.lifeform })
    assert_equal(first_updated_at, name.observations.first.updated_at)
  end

  # Prove that changing a name will update observations.text_name for
  # all the attached observations without changing the updated_at field.
  def test_changing_text_name
    name = names(:stereum_hirsutum)
    assert_not_empty(name.observations)
    first_updated_at = name.observations.first.updated_at
    name.change_text_name("Stereum blah", "Foo", :Species)
    name.save
    assert(name.observations.all? { |o| o.text_name == name.text_name })
    assert_equal(first_updated_at, name.observations.first.updated_at)
  end

  # Prove that changing a name's classification will update
  # observations.classification for all the attached observations without
  # changing the updated_at field. 
  def test_changing_classification
    name = names(:peltigera)
    desc = name.description
    assert_not_nil(desc)
    assert_not_empty(name.observations)
    name_updated_at = name.updated_at
    first_updated_at = name.observations.first.updated_at
    new_str = desc.classification.sub(/Ascomycota/, "Basidiomycota")
    desc.update_attributes(classification: new_str)
    assert_equal(new_str, name.reload.classification)
    assert(name.observations.all? { |o| o.classification == new_str })
    # Name modification date is updated, but not observations.
    assert_not_equal(name_updated_at, name.updated_at)
    assert_equal(first_updated_at, name.observations.first.updated_at)
  end

  # propagate_classification
  # propagate_generic_classifications
  # refresh_classification_caches
  # propagate_add_lifeform
  # propagate_remove_lifeform
end
