# frozen_string_literal: true

require("test_helper")

class LabelsTest < UnitTestCase
  def test_mo_id
    id = observations(:minimal_unknown_obs).id
    label = Labels.new(Query.lookup(:Observation, id_in_set: [id]))
    assert_match("MO #{id}", label.body)
  end

  def test_name_has_space
    obs = observations(:coprinus_comatus_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match(/Coprinus.*?[ ]+.*?comatus/m, label.body)
  end

  def test_inat_id
    obs = observations(:imported_inat_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("iNat #{obs.inat_id}", label.body)
  end

  def test_collector_and_observer
    obs = observations(:template_and_orphaned_notes_scrambled_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("Observer", label.body)
    assert_match("Collector", label.body)
  end

  def test_matching_collector_and_observer
    obs = observations(:current_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_no_match("Observer", label.body)
    assert_match("Collector", label.body)
  end

  def test_no_collector
    obs = observations(:coprinus_comatus_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_no_match("Observer", label.body)
    assert_match("Collector", label.body)
  end

  def test_with_lat_lng_alt
    obs = observations(:unknown_with_lat_lng)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("#{obs.lat.abs}", label.body)
    assert_match("#{obs.lng.abs}", label.body)
    assert_match("#{obs.alt.abs} m", label.body)
  end

  def test_with_lat_lng_alt
    obs = observations(:unknown_with_lat_lng)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("#{obs.lat.abs}", label.body)
    assert_match("#{obs.lng.abs}", label.body)
    assert_match("#{obs.alt.abs} m", label.body)
  end

  def test_low_alt
    obs = observations(:low_alt_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("#{obs.location.low.round}", label.body)
  end

  def test_high_alt
    obs = observations(:high_alt_obs)
    label = Labels.new(Query.lookup(:Observation, id_in_set: [obs.id]))
    assert_match("#{obs.location.high.round}", label.body)
  end
end
