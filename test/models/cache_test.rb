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

  # Prove that when an observation's name changes from voting that the
  # caches will also be updated appropriately.
  def test_changing_observation_name
    obs      = observations(:coprinus_comatus_obs)
    old_name = obs.name
    naming   = obs.namings.select { |n| n.name != old_name }.first
    new_name = naming.name
    assert_not_equal("", new_name.lifeform.to_s)
    assert_not_equal("", new_name.classification.to_s)
    naming.votes.each do |vote|
      obs.change_vote(naming, Vote.maximum_vote, vote.user)
    end
    assert_names_equal(new_name, obs.reload.name)
    assert_equal(new_name.lifeform, obs.lifeform)
    assert_equal(new_name.text_name, obs.text_name)
    assert_equal(new_name.classification, obs.classification)
  end

  # Prove that observation caches are updated when a classification is bulk-
  # changed in all of a genus's subtaxa (and that updated_at not changed).
  def test_propagate_classification
    name = names(:agaricus)
    new_classification = names(:peltigera).classification
    name.update_attributes(classification: new_classification)
    name.propagate_classification
    Observation.where("text_name LIKE 'Agaricus%'").each do |obs|
      assert_equal(new_classification, obs.classification)
      assert_operator(obs.updated_at, :<, 1.minute.ago)
    end
  end

  # Prove that bulk changing lifeform also updates corresponding observation
  # caches (and does not touch updated_at).
  def test_propagate_lifeform
    name = names(:agaricus)
    name.propagate_add_lifeform("lichen")
    Observation.where("text_name LIKE 'Agaricus %'").each do |obs|
      assert_true(obs.lifeform.include?(" lichen "))
      assert_operator(obs.updated_at, :<, 1.minute.ago)
    end
    name.propagate_remove_lifeform("lichen")
    Observation.where("text_name LIKE 'Agaricus %'").each do |obs|
      assert_false(obs.lifeform.include?(" lichen "))
      assert_operator(obs.updated_at, :<, 1.minute.ago)
    end
  end

  # def test_cronjob_refresh_caches
  #   # First "break" the cache; update_columns avoids the callbacks which would
  #   # normally propagate the changes to the affected names and observations.
  #
  #   # The name_description is the most-upstream source for classification.
  #   new_str = names(:peltigera).classification
  #   desc = name_descriptions(:coprinus_desc)
  #   desc.update_columns(classification: new_str)
  #
  #   # Also break all the mirrored columns in one observation.
  #   obs = observations(:agaricus_campestris_obs)
  #   assert_not_equal(" lichen ", obs.name.lifeform)
  #   assert_not_equal("Spam spam", obs.name.text_name)
  #   assert_not_equal(new_str, obs.name.classification)
  #   assert_not_equal("Antarctica", obs.location.name)
  #   obs.update_columns(
  #     lifeform: " lichen ",
  #     text_name: "Spam spam",
  #     classification: new_str,
  #     where: "Antarctica"
  #   )
  #
  #   # Make sure there is an observation associated with the genus Coprinus.
  #   Observation.create!(
  #     where: Location.unknown,
  #     when: Time.now,
  #     name: names(:coprinus),
  #     user: rolf
  #   )
  #
  #   # Now run the nightly cronjob which will first update the name Coprinus,
  #   # and then propagate that change to all the subtaxa of Coprinus, as well
  #   # as the observations associated with all those names.
  #   Name.refresh_classification_caches
  #   Name.propagate_generic_classifications
  #   Observation.refresh_content_filter_caches
  #
  #   # Make sure the name, its subtaxa and related observations' classification
  #   # was updated first.  (This will include the new observation of Coprinus.)
  #   Name.where("text_name LIKE 'Coprinus%'").each do |name|
  #     assert_equal(new_str, name.classification,
  #                  "The name #{name.search_name} is wrong.")
  #   end
  #   Observation.where("text_name LIKE 'Coprinus%'").each do |obs|
  #     assert_equal(new_str, obs.classification,
  #                  "The name #{fixture_label(obs)} is wrong.")
  #   end
  #
  #   # Make sure the broken observation was also fixed.
  #   assert_equal(obs.name.lifeform, obs.reload.lifeform)
  #   assert_equal(obs.name.text_name, obs.reload.text_name)
  #   assert_equal(obs.name.classification, obs.reload.classification)
  #   assert_equal(obs.location.name, obs.reload.where)
  # end
end
