require "test_helper"

class ObservationReportTest < UnitTestCase
  def do_csv_test(report_type, obs, expect, &block)
    query = Query.lookup(:Observation, :all)
    report = report_type.new(query: query).body
    assert_not_empty(report)
    table = CSV.parse(report)
    assert_equal(query.num_results + 1, table.count)
    idx = query.results.sort_by(&block).index(obs)
    assert_equal(expect, table[idx + 1])
  end

  def do_tsv_test(report_type, obs, expect, &block)
    query = Query.lookup(:Observation, :all)
    report = report_type.new(query: query).body
    assert_not_empty(report)
    rows = report.split("\n")
    assert_equal(query.num_results + 1, rows.length)
    idx = query.results.sort_by(&block).index(obs)
    assert_equal(expect, rows[idx + 1].split("\t"))
  end

  # ----------------------------------------------------------------------------

  def test_adolf
    obs = observations(:agaricus_campestris_obs)
    expect = [
      nil,
      nil,
      nil,
      "Agaricus",
      nil,
      "campestris",
      "L.",
      nil,
      nil,
      nil,
      nil,
      "USA",
      "California",
      "Burbank",
      "34.15",
      "-118.37",
      "34.22",
      "-118.29",
      nil,
      nil,
      nil,
      nil,
      "2007-03-19",
      "Rolf Singer",
      nil,
      nil,
      nil,
      "From the lawn next door",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      obs.id.to_s,
      nil
    ]
    do_csv_test(ObservationReport::Adolf, obs, expect, &:text_name)
  end

  def test_darwin
    obs = observations(:detailed_unknown_obs)
    expect = [
      "2006-05-12 17:21:00 UTC",
      "MushroomObserver",
      nil,
      obs.id.to_s,
      "Fungi",
      nil,
      "Kingdom",
      "Fungi",
      nil,
      nil,
      "Mary Newbie",
      "2006-05-11",
      "2006",
      "5",
      "11",
      "USA",
      "California",
      nil,
      "Burbank",
      "34.185",
      "-118.33",
      "148",
      "294",
      "Found in a strange place... & with śtrangè characters™"
    ]
    do_csv_test(ObservationReport::Darwin, obs, expect, &:id)
  end

  def test_mycoflora_no_exact_lat_long
    # There are two collection numbers for this observation.  I can't think of
    # any good way to ensure the order that these are rendered in the report be
    # consistent.  So I'm just going to delete one of the numbers.
    collection_numbers(:detailed_unknown_coll_num_two).destroy

    obs = observations(:detailed_unknown_obs)
    img1, img2 = obs.images.sort_by(&:id)
    expect = [
      "Fungi",
      nil,
      "Mary Newbie",
      "MO #{obs.id}; Mary Newbie 174",
      "MO #{obs.id}",
      "",
      "1",
      "Burbank",
      nil,
      "California",
      "USA",
      "34.185",
      "-118.33",
      "3892",
      "148",
      "294",
      "11",
      "5",
      "2006",
      "2006-05-11",
      "http://mushroomobserver.org/#{obs.id}",
      "/remote_images/orig/#{img1.id}.jpg " \
        "/remote_images/orig/#{img2.id}.jpg",
      "NA Mycoflora Project",
      "",
      "",
      "",
      "",
      "Found in a strange place... & with śtrangè characters™"
    ]
    do_csv_test(ObservationReport::Mycoflora, obs, expect, &:id)
  end

  def test_mycoflora_with_exact_lat_long
    obs = observations(:unknown_with_lat_long)
    obs.notes = {
      "Collector's_Name": "John Doe",
      Substrate: "wood chips",
      Habitat: "lawn",
      Host: "_Agaricus_",
      Foo: "Bar",
      Other: "Things"
    }
    obs.save!

    expect = [
      "Fungi",
      nil,
      "Mary Newbie",
      "MO #{obs.id}",
      "MO #{obs.id}",
      "",
      "0",
      "Burbank",
      nil,
      "California",
      "USA",
      "34.1622",
      "-118.3521",
      nil,
      "123",
      "123",
      "22",
      "7",
      "2010",
      "2010-07-22",
      "http://mushroomobserver.org/#{obs.id}",
      "",
      "NA Mycoflora Project",
      "John Doe",
      "wood chips",
      "lawn",
      "Agaricus",
      "Foo: Bar\nOther: Things"
    ]
    do_csv_test(ObservationReport::Mycoflora, obs, expect, &:id)
  end

  def test_mycoflora_with_hidden_gps
    obs = observations(:unknown_with_lat_long)
    obs.update_attribute(:gps_hidden, true)

    expect = [
      "Fungi",
      nil,
      "Mary Newbie",
      "MO #{obs.id}",
      "MO #{obs.id}",
      "",
      "0",
      "Burbank",
      nil,
      "California",
      "USA",
      "34.185",
      "-118.33",
      "3892",
      "123",
      "123",
      "22",
      "7",
      "2010",
      "2010-07-22",
      "http://mushroomobserver.org/#{obs.id}",
      "",
      "NA Mycoflora Project",
      "",
      "",
      "",
      "",
      "unknown_with_lat_long"
    ]
    do_csv_test(ObservationReport::Mycoflora, obs, expect, &:id)

    User.current = mary
    expect[11] = "34.1622"
    expect[12] = "-118.3521"
    expect[13] = nil
    do_csv_test(ObservationReport::Mycoflora, obs, expect, &:id)
  end

  def test_raw
    obs = observations(:detailed_unknown_obs)
    expect = [
      obs.id.to_s,
      obs.user.id.to_s,
      "mary",
      "Mary Newbie",
      "2006-05-11",
      "X",
      "Cortinarius sp.: 1234, Fungi: 314159",
      obs.name.id.to_s,
      "Fungi",
      nil,
      "Kingdom",
      "0.0",
      "547147019",
      "USA",
      "California",
      nil,
      "Burbank",
      nil,
      nil,
      nil,
      "34.22",
      "34.15",
      "-118.29",
      "-118.37",
      "294",
      "148",
      "X",
      obs.thumb_image.id.to_s,
      "Found in a strange place... & with śtrangè characters™",
      "http://mushroomobserver.org/#{obs.id}"
    ]
    do_csv_test(ObservationReport::Raw, obs, expect, &:id)
  end

  def test_symbiota1
    obs = observations(:detailed_unknown_obs)
    obs.notes = {
      Substrate: "wood\tchips",
      Habitat: "lawn",
      Host: "_Agaricus_",
      Other: "First\tline.\nSecond\tline."
    }
    obs.save!

    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    expect = [
      "Fungi",
      "",
      "Kingdom",
      "Fungi",
      "",
      "",
      "Mary Newbie",
      "174",
      "NY",
      "2006-05-11",
      "2006",
      "5",
      "11",
      "USA",
      "California",
      "",
      "Burbank",
      "34.185",
      "-118.33",
      "148",
      "294",
      "#{obs.updated_at.api_time} UTC",
      'wood chips',
      "Agaricus",
      'Habitat: lawn Other: First line. Second line.',
      obs.id.to_s,
      "http://mushroomobserver.org/#{obs.id}",
      "http://mushroomobserver.org/images/orig/#{img1.id}.jpg " \
        "http://mushroomobserver.org/images/orig/#{img2.id}.jpg"
    ]
    do_tsv_test(ObservationReport::Symbiota, obs, expect, &:id)
  end

  def test_symbiota2
    obs = observations(:agaricus_campestrus_obs)
    expect = [
      "Agaricus campestrus",
      "L.",
      "Species",
      "Agaricus",
      "campestrus",
      "",
      "Rolf Singer",
      "MUOB #{obs.id}",
      "",
      "2007-06-23",
      "2007",
      "6",
      "23",
      "USA",
      "California",
      "",
      "Burbank",
      "34.185",
      "-118.33",
      "148",
      "294",
      "#{obs.updated_at.api_time} UTC",
      "",
      "",
      "From somewhere else",
      obs.id.to_s,
      "http://mushroomobserver.org/#{obs.id}"
    ]
    do_tsv_test(ObservationReport::Symbiota, obs, expect, &:id)
  end

  def test_rounding_of_latitudes_etc
    row = ObservationReport::Row.new(vals = [])
    vals[2] = 1.20456
    assert_equal(1.2, row.obs_lat(2))
    assert_equal(1.205, row.obs_lat(3))
    assert_equal(1.2046, row.obs_lat(4))
    vals[2] = -123.00045
    assert_equal(-123, row.obs_lat(3))
    assert_equal(-123.0005, row.obs_lat(4))
    assert_equal(-123.00045, row.obs_lat(5))
    vals[4] = 123.4999
    assert_equal(123, row.obs_alt)
    vals[4] = -123.5000
    assert_equal(-124, row.obs_alt)
  end

  def test_cleaning_of_notes
    row = ObservationReport::Row.new(vals = [])
    vals[9] = { Observation.other_notes_key => " abc  def " }.to_yaml
    assert_equal("abc  def", row.obs_notes)
  end

  def test_split_date
    row = ObservationReport::Row.new(vals = [])
    vals[1] = "2017-01-03"
    assert_equal("2017", row.year)
    assert_equal("1", row.month)
    assert_equal("3", row.day)
  end

  def test_split_location
    row = ObservationReport::Row.new(vals = [])
    vals[19] = "Park, Random, Some, Alameda Co., California, USA"
    assert_equal("USA", row.country)
    assert_equal("California", row.state)
    assert_equal("Alameda", row.county)
    assert_equal("Some, Random, Park", row.locality)
    assert_equal("Alameda Co., Some, Random, Park", row.locality_with_county)

    row = ObservationReport::Row.new(vals = [])
    vals[19] = "Big Branch, Saint Tammany Parish, Louisiana, USA"
    assert_equal("USA", row.country)
    assert_equal("Louisiana", row.state)
    assert_equal("Saint Tammany", row.county)
    assert_equal("Big Branch", row.locality)
    assert_equal("Saint Tammany Parish, Big Branch", row.locality_with_county)

    row = ObservationReport::Row.new(vals = [])
    vals[19] = "Central Park, Los Angeles, California, USA"
    assert_equal("USA", row.country)
    assert_equal("California", row.state)
    assert_nil(row.county)
    assert_equal("Los Angeles, Central Park", row.locality)
    assert_equal("Los Angeles, Central Park", row.locality_with_county)
  end

  def do_split_test(name, author, rank, expect)
    row = ObservationReport::Row.new(vals = [])
    vals[15] = name
    vals[16] = author
    vals[17] = Name.ranks[rank]
    assert_equal(expect[:genus].to_s, row.genus.to_s)
    assert_equal(expect[:species].to_s, row.species.to_s)
    assert_equal(expect[:subspecies].to_s, row.subspecies.to_s)
    assert_equal(expect[:variety].to_s, row.variety.to_s)
    assert_equal(expect[:form].to_s, row.form.to_s)
    assert_equal(expect[:species_author].to_s, row.species_author.to_s)
    assert_equal(expect[:subspecies_author].to_s, row.subspecies_author.to_s)
    assert_equal(expect[:variety_author].to_s, row.variety_author.to_s)
    assert_equal(expect[:form_author].to_s, row.form_author.to_s)
    assert_equal(expect[:cf].to_s, row.cf.to_s)
  end

  def test_split_name
    do_split_test("Fungi", "Bartl.", :Kingdom, genus: "Fungi")
    do_split_test("Agaricus", "L.", :Genus, genus: "Agaricus")
    do_split_test("Rhizocarpon geographicum group", "", :Group,
                  genus: "Rhizocarpon",
                  species: "geographicum group")
    do_split_test("Rhizocarpon geographicum group", "sensu MO", :Group,
                  genus: "Rhizocarpon",
                  species: "geographicum group",
                  species_author: "sensu MO")
    do_split_test("Rhizocarpon geographicum", "", :Species,
                  genus: "Rhizocarpon",
                  species: "geographicum")
    do_split_test("Rhizocarpon geographicum", "(L.) DC.", :Species,
                  genus: "Rhizocarpon",
                  species: "geographicum",
                  species_author: "(L.) DC.")
    do_split_test("Some thing ssp. else", "", :Subspecies,
                  genus: "Some",
                  species: "thing",
                  subspecies: "else")
    do_split_test("Some thing ssp. else", "Seuss", :Subspecies,
                  genus: "Some",
                  species: "thing",
                  subspecies: "else",
                  subspecies_author: "Seuss")
    do_split_test("Some thing var. else", "Seuss", :Variety,
                  genus: "Some",
                  species: "thing",
                  variety: "else",
                  variety_author: "Seuss")
    do_split_test("Some thing f. else", "Seuss", :Form,
                  genus: "Some",
                  species: "thing",
                  form: "else",
                  form_author: "Seuss")
    do_split_test("Some thing ssp. else var. or f. other cfr.", "Seuss", :Form,
                  genus: "Some",
                  species: "thing",
                  subspecies: "else",
                  variety: "or",
                  form: "other",
                  form_author: "Seuss",
                  cf: "cf.")
  end
end
