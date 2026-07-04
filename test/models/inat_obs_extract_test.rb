# frozen_string_literal: true

require("test_helper")

class InatObsExtractTest < UnitTestCase
  # A single raw iNat observation hash, as the API returns it inside
  # `results`. Mirrors test/classes/inat_obs_test.rb's fixture loading.
  def raw_obs(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end

  def test_from_raw_extracts_comparison_fields
    raw = raw_obs("somion_unicolor")
    extract = InatObsExtract.from_raw(raw, fetched_at: Time.current)

    assert_equal(raw[:id], extract.inat_id)
    assert_equal("jdcohenesq", extract.inat_login)
    assert_equal(Date.new(2023, 3, 23), extract.observed_on)
    assert_in_delta(31.8813, extract.lat.to_f, 0.001)
    assert_in_delta(-109.244, extract.lng.to_f, 0.01)
    assert_equal(20, extract.public_accuracy)
    assert_not(extract.obscured)
    assert_equal("Somion unicolor", extract.taxon_name)
    assert_equal("species", extract.taxon_rank)
    assert_equal("Cochise Co., Arizona, USA", extract.place_guess)
  end

  def test_from_raw_extracts_photos_at_medium_size
    extract = InatObsExtract.from_raw(raw_obs("somion_unicolor"),
                                      fetched_at: Time.current)

    assert_not_empty(extract.photos)
    photo = extract.photos.first

    assert_equal(357_753_797, photo["id"])
    assert_includes(photo["url"], "/medium.")
    assert_not_includes(photo["url"], "square")
  end

  def test_upsert_is_idempotent_and_updates
    raw = raw_obs("somion_unicolor")
    first = InatObsExtract.upsert_from_raw(raw, fetched_at: Time.current)

    assert_equal(1, InatObsExtract.where(inat_id: raw[:id]).count)

    raw[:place_guess] = "Somewhere else"
    second = InatObsExtract.upsert_from_raw(raw, fetched_at: Time.current)

    assert_equal(first.id, second.id)
    assert_equal(1, InatObsExtract.where(inat_id: raw[:id]).count)
    assert_equal("Somewhere else", second.reload.place_guess)
  end

  def test_requires_inat_id_and_fetched_at
    extract = InatObsExtract.new

    assert_not(extract.valid?)
    assert_includes(extract.errors.attribute_names, :inat_id)
    assert_includes(extract.errors.attribute_names, :fetched_at)
  end
end
