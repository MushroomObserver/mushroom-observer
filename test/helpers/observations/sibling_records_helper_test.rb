# frozen_string_literal: true

require("test_helper")

# Tests for Observations::SiblingRecordsHelper
class SiblingRecordsHelperTest < ActionView::TestCase
  include Observations::SiblingRecordsHelper

  def test_sibling_collection_numbers_with_records
    cn = collection_numbers(:coprinus_comatus_coll_num)
    sibling = cn.observations.first
    html = sibling_collection_numbers([sibling])

    assert_match("tight-list", html)
    assert_match(cn.format_name, html)
    assert_match("MO #{sibling.id}", html)
  end

  def test_sibling_collection_numbers_empty
    obs = observations(:strobilurus_diminutivus_obs)
    result = sibling_collection_numbers([obs])
    assert_nil(result)
  end

  def test_sibling_herbarium_records_with_records
    hr = herbarium_records(:coprinus_comatus_rolf_spec)
    sibling = hr.observations.first
    html = sibling_herbarium_records([sibling])

    assert_match("tight-list", html)
    assert_match(sibling.id.to_s, html)
  end

  def test_sibling_herbarium_records_empty
    obs = observations(:strobilurus_diminutivus_obs)
    result = sibling_herbarium_records([obs])
    assert_nil(result)
  end

  def test_sibling_sequences_with_records
    seq = sequences(:local_sequence)
    sibling = seq.observation
    html = sibling_sequences([sibling])

    assert_match("tight-list", html)
    assert_match(seq.format_name, html)
    assert_match("MO #{sibling.id}", html)
  end

  def test_sibling_sequences_empty
    obs = observations(:strobilurus_diminutivus_obs)
    result = sibling_sequences([obs])
    assert_nil(result)
  end

  def test_sibling_external_link_items_with_links
    el = external_links(:coprinus_comatus_obs_mycoportal_link)
    sibling = el.observation
    html = sibling_external_link_items([sibling])

    assert_match("<li>", html)
    assert_match(el.url, html)
    assert_match("MO #{sibling.id}", html)
  end

  def test_sibling_external_link_items_empty
    obs = observations(:strobilurus_diminutivus_obs)
    result = sibling_external_link_items([obs])
    assert_equal("", result)
  end

  def test_sibling_attribution_includes_obs_link
    obs = observations(:minimal_unknown_obs)
    html = sibling_attribution(obs)
    assert_match("MO #{obs.id}", html)
    assert_match("text-muted", html)
  end
end
