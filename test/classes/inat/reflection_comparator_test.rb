# frozen_string_literal: true

require("test_helper")

class Inat::ReflectionComparatorTest < UnitTestCase
  # dHashes with known Hamming distances from 0. SAME_PHOTO_MAX_DISTANCE is
  # 8, so NEAR (4 bits) matches 0 and FAR/FAR2 (>8 bits, and 64 bits apart
  # from each other) do not match anything.
  ZERO = 0
  NEAR = 0b1111                       # distance 4 from ZERO -> match
  FAR  = 0xFFFFFFFF00000000           # distance 32 from ZERO
  FAR2 = 0x00000000FFFFFFFF           # distance 32 from ZERO, 64 from FAR

  def test_image_relations
    assert_equal(:no_images, relation([], []))
    assert_equal(:identical, relation([ZERO], [NEAR]))
    assert_equal(:mo_subset_of_inat, relation([ZERO], [NEAR, FAR]))
    assert_equal(:inat_subset_of_mo, relation([ZERO, FAR], [NEAR]))
    assert_equal(:overlapping, relation([ZERO, FAR], [NEAR, FAR2]))
    assert_equal(:disjoint, relation([ZERO], [FAR]))
    # Empty MO images but iNat has some: MO's (empty) set is a subset.
    assert_equal(:mo_subset_of_inat, relation([], [ZERO]))
  end

  def test_case_numbers
    assert_equal(1, compare([ZERO], [NEAR]).case_number)          # identical
    assert_equal(1, compare([ZERO], [NEAR, FAR]).case_number)     # mo subset
    assert_equal(2, compare([ZERO, FAR], [NEAR]).case_number)     # inat subset
    assert_equal(3, compare([ZERO], [FAR]).case_number)           # disjoint
    assert_equal(4, compare([ZERO, FAR], [NEAR, FAR2]).case_number) # overlap
  end

  def test_matched_count_is_one_to_one
    # Two identical MO images against one iNat photo: only one can match.
    result = compare([ZERO, ZERO], [ZERO])

    assert_equal(1, result.matched_image_count)
    assert_equal(:inat_subset_of_mo, result.image_relation)
  end

  def test_matches_rotated_inat_photo
    # The MO image matches only a rotated version of the iNat photo — the
    # iNat entry is that photo's set of rotation hashes, and one (NEAR) is
    # within threshold. Without rotation-awareness this would be disjoint.
    result = compare([ZERO], [[FAR, FAR2, NEAR, FAR]])

    assert_equal(:identical, result.image_relation)
    assert_equal(1, result.matched_image_count)
  end

  def test_field_matches
    obs = fake_obs(when: Date.new(2023, 8, 25), lat: 35.2279, lng: -82.5433,
                   text_name: "Aureoboletus betula")
    extract = InatObsExtract.new(observed_on: Date.new(2023, 8, 25),
                                 lat: 35.2279, lng: -82.5433, obscured: false,
                                 taxon_name: "aureoboletus betula")
    result = build(obs, extract, [], []).compare

    assert_equal(:match, result.date_status)
    assert_equal(:match, result.location_status)
    assert_equal(0, result.location_meters)
    assert_equal(:match, result.taxon_status) # case-insensitive
  end

  def test_field_statuses_are_na_without_data
    result = build(fake_obs, InatObsExtract.new, [], []).compare

    assert_equal(:na, result.date_status)
    assert_equal(:na, result.location_status)
    assert_nil(result.location_meters)
    assert_equal(:na, result.taxon_status)
  end

  def test_obscured_coordinates_are_not_a_location_edit
    obs = fake_obs(lat: 35.2279, lng: -82.5433)
    # iNat public point ~7km away, but obscured with 28.7km accuracy.
    extract = InatObsExtract.new(lat: 35.2899, lng: -82.4103,
                                 obscured: true, public_accuracy: 28_706)

    assert_equal(:match, build(obs, extract, [], []).compare.location_status)
  end

  def test_falls_back_to_location_centroid_when_no_point
    # No obs point, but a Location centroid that matches the iNat point.
    obs = fake_obs(location_lat: 35.2279, location_lng: -82.5433)
    extract = InatObsExtract.new(lat: 35.2279, lng: -82.5433, obscured: false)
    result = build(obs, extract, [], []).compare

    assert_equal(:location, result.mo_coord_source)
    assert_equal(:match, result.location_status)
    assert_equal(0, result.location_meters)
  end

  def test_unobscured_distant_coordinates_do_not_match
    obs = fake_obs(lat: 35.2279, lng: -82.5433)
    extract = InatObsExtract.new(lat: 40.0, lng: -80.0, obscured: false)

    assert_equal(:differ, build(obs, extract, [], []).compare.location_status)
  end

  def test_centroid_source_tolerates_the_whole_named_area
    # No obs point; a large named Location whose centroid is ~70 km from the
    # iNat point, but the point is well within the box. Without the radius
    # tolerance this coarse centroid would read as a location edit.
    obs = fake_obs(location_lat: 34.0, location_lng: -109.5)
    box = fake_box(north: 34.6, south: 33.4, east: -108.8, west: -110.2)
    extract = InatObsExtract.new(lat: 33.5, lng: -109.0, obscured: false)
    result = build(obs, extract, [], [], box: box).compare

    assert_equal(:location, result.mo_coord_source)
    assert_operator(result.location_meters, :>, 50_000)
    assert_equal(:match, result.location_status)
  end

  def test_point_outside_its_own_location_is_gps_suspect
    # MO point near the South Pole, but the named Location and the iNat
    # point are both in Pennsylvania: the point is corrupt, not an edit.
    obs = fake_obs(lat: -79.2372, lng: 113.71,
                   location_lat: 41.139, location_lng: -77.444)
    box = fake_box(north: 41.154, south: 41.124, east: -77.414, west: -77.475)
    extract = InatObsExtract.new(lat: 41.1388, lng: -77.4443, obscured: false)

    result = build(obs, extract, [], [], box: box).compare
    assert_equal(:mo_gps_suspect, result.location_status)
  end

  def test_corrupt_point_with_inat_also_elsewhere_is_plain_differ
    # MO point is outside its box, but iNat's point is nowhere near the
    # named Location either — no basis to blame the MO point specifically.
    obs = fake_obs(lat: -79.2372, lng: 113.71,
                   location_lat: 41.139, location_lng: -77.444)
    box = fake_box(north: 41.154, south: 41.124, east: -77.414, west: -77.475)
    extract = InatObsExtract.new(lat: 10.0, lng: 10.0, obscured: false)

    result = build(obs, extract, [], [], box: box).compare
    assert_equal(:differ, result.location_status)
  end

  private

  def fake_box(north:, south:, east:, west:)
    Struct.new(:north, :south, :east, :west, keyword_init: true).
      new(north: north, south: south, east: east, west: west)
  end

  # `when` is a reserved word; the label form (`when:`) is fine as a kwarg
  # key, and Struct members with that name read back via `obj.when`.
  def fake_obs(**attrs)
    Struct.new(:when, :lat, :lng, :location_lat, :location_lng, :text_name,
               keyword_init: true).new(**attrs)
  end

  def build(obs, extract, mo_hashes, inat_hashes, box: nil)
    Inat::ReflectionComparator.new(mo_obs: obs, extract: extract,
                                   mo_hashes: mo_hashes,
                                   inat_hashes: inat_hashes, mo_box: box)
  end

  def relation(mo_hashes, inat_hashes)
    # image_relation reads only the hash lists, not obs/extract.
    build(nil, nil, mo_hashes, inat_hashes).image_relation
  end

  def compare(mo_hashes, inat_hashes)
    build(fake_obs, InatObsExtract.new, mo_hashes, inat_hashes).compare
  end
end
