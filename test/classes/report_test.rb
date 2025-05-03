# frozen_string_literal: true

require("test_helper")

class ReportTest < UnitTestCase
  LAT_INDEX = 17
  LONG_INDEX = 18

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
    do_csv_test(Report::Adolf, obs, expect, &:text_name)
  end

  def test_darwin_observations
    obs = observations(:detailed_unknown_obs)
    expect = [
      obs.id.to_s,
      "#{MO.http_domain}/#{obs.id}",
      "HumanObservation",
      "#{obs.updated_at.api_time} UTC",
      "MushroomObserver",
      nil,
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
    do_csv_test(Report::Darwin::Observations, obs, expect, &:id)
  end

  def test_dwca
    expect = ["meta.xml", "observations.csv", "multimedia.csv"]
    do_zip_test(Report::Dwca, expect)
  end

  def test_taxa_report
    taxa_report = build_taxa_report
    report_content = taxa_report.body
    assert_not_empty(report_content)
    table = CSV.parse(report_content, col_sep: taxa_report.separator)
    assert_equal(Observation.select(:name_id).distinct.count + 1, table.count)
    obs = Observation.first
    assert(table.include?([obs.name_id.to_s, obs.text_name]))
  end

  def test_fundis_no_exact_lat_lng
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
      "MO#{obs.id}; Mary Newbie 174",
      "MO#{obs.id}",
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
      "https://mushroomobserver.org/#{obs.id}",
      "file://#{Rails.root.join("public/test_server1/orig/#{img1.id}.jpg ")}" \
        "file://#{Rails.root.join("public/test_server1/orig/#{img2.id}.jpg")}",
      "FunDiS",
      "",
      "",
      "",
      "",
      "Found in a strange place... & with śtrangè characters™"
    ]
    do_csv_test(Report::Fundis, obs, expect, &:id)
  end

  def test_fundis_with_exact_lat_lng
    obs = observations(:unknown_with_lat_lng)
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
      "MO#{obs.id}",
      "MO#{obs.id}",
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
      "https://mushroomobserver.org/#{obs.id}",
      "",
      "FunDiS",
      "John Doe",
      "wood chips",
      "lawn",
      "Agaricus",
      "Foo: Bar\nOther: Things"
    ]
    do_csv_test(Report::Fundis, obs, expect, &:id)
  end

  def test_fundis_with_hidden_gps
    obs = observations(:unknown_with_lat_lng)
    obs.update_attribute(:gps_hidden, true)

    expect = [
      "Fungi",
      nil,
      "Mary Newbie",
      "MO#{obs.id}",
      "MO#{obs.id}",
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
      "https://mushroomobserver.org/#{obs.id}",
      "",
      "FunDiS",
      "",
      "",
      "",
      "",
      "unknown_with_lat_lng"
    ]
    do_csv_test(Report::Fundis, obs, expect, &:id)

    expect[11] = "34.1622"
    expect[12] = "-118.3521"
    expect[13] = nil
    do_csv_test(Report::Fundis, obs, expect, user: users(:mary), &:id)
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
      "https://mushroomobserver.org/#{obs.id}"
    ]
    do_csv_test(Report::Raw, obs, expect, &:id)
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
      "wood chips",
      "Agaricus",
      "Habitat: lawn Other: First line. Second line.",
      obs.id.to_s,
      "https://mushroomobserver.org/#{obs.id}",
      "https://mushroomobserver.org/images/orig/#{img1.id}.jpg " \
        "https://mushroomobserver.org/images/orig/#{img2.id}.jpg"
    ]
    do_tsv_test(Report::Symbiota, obs, expect, &:id)
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
      "https://mushroomobserver.org/#{obs.id}"
    ]
    do_tsv_test(Report::Symbiota, obs, expect, &:id)
  end

  def test_symbiota_compress_consecutive_whitespace
    obs = observations(:detailed_unknown_obs)
    obs.notes = {
      Substrate: "wood\tchips",
      Habitat: "lawn",
      Host: "_Agaricus_",
      Other: "1st line.\r\n\r\n2nd line.\r\n \r\n3rd line."
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
      "wood chips",
      "Agaricus",
      "Habitat: lawn Other: 1st line. 2nd line. 3rd line.",
      obs.id.to_s,
      "https://mushroomobserver.org/#{obs.id}",
      "https://mushroomobserver.org/images/orig/#{img1.id}.jpg " \
        "https://mushroomobserver.org/images/orig/#{img2.id}.jpg"
    ]
    do_tsv_test(Report::Symbiota, obs, expect, &:id)
  end

  # test bare-bones obs to differentiate from other tests
  def test_mycoportal_minimal
    obs = observations(:minimal_unknown_obs)
    expect = hashed_expect(obs).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_notes_and_images
    obs = observations(:detailed_unknown_obs)
    obs.notes = {
      Substrate: "wood\tchips",
      Habitat: "lawn",
      Host: "_Agaricus_",
      Other: "First\tline.\nSecond\tline."
    }
    obs.save!

    expect = hashed_expect(obs).merge(
      disposition: "NY",
      substrate: "wood chips",
      associatedTaxa: "host: Agaricus",
      occurrenceRemarks: "Habitat: lawn Other: First line. Second line."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_sequence
    obs = observations(:locally_sequenced_obs)
    expect = hashed_expect(obs).merge(
      occurrenceRemarks: "Sequenced; ",
      locality: "North Falmouth, 68 Bay Rd., MO Inc."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_agaricus_campestrus_obs
    obs = observations(:agaricus_campestrus_obs)
    expect = hashed_expect(obs).merge(
      scientificNameAuthorship: "L.",
      occurrenceRemarks: "From somewhere else"
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_compress_consecutive_whitespace
    obs = observations(:detailed_unknown_obs)
    obs.notes = {
      Substrate: "wood\tchips",
      Habitat: "lawn",
      Host: "_Agaricus_",
      Other: "1st line.\r\n\r\n2nd line.\r\n \r\n3rd line."
    }
    obs.save!

    expect = hashed_expect(obs).merge(
      disposition: "NY",
      substrate: "wood chips",
      associatedTaxa: "host: Agaricus",
      occurrenceRemarks: "Habitat: lawn Other: 1st line. 2nd line. 3rd line."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_associated_taxa_trees_shrubs_host
    obs = observations(:detailed_unknown_obs)
    obs.notes = {
      FieldSlip::TREES_SHRUBS => "oak, pine",
      Host: "Pinus contorta",
      Other: "other remarks"
    }
    obs.save!

    expect = hashed_expect(obs).merge(
      disposition: "NY",
      # https://github.com/BioKIC/symbiota-docs/issues/36#issuecomment-1015733243
      associatedTaxa: "oak, pine; host: Pinus contorta",
      occurrenceRemarks: "other remarks"
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_group
    location = locations(:burbank)
    name = names(:boletus_edulis_group)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      sciname: "Boletus edulis",
      scientificNameAuthorship: "Bull.",
      identificationQualifier: "group"
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_group_sensu
    name = Name.create!(
      user: rolf,
      rank: "Group",
      text_name: "Tricholoma caligatum group",
      author: "sensu Besette et al.",
      search_name: "Tricholoma caligatum group sensu Besette et al.",
      display_name: "**__Tricholoma__** **__caligatum__** group " \
                    "sensu Besette et al."
    )
    unqualified_name = Name.create!(
      user: rolf,
      rank: "Species",
      text_name: "Tricholoma caligatum",
      author: "(Viv.) Ricken",
      search_name: "Tricholoma caligatum (Viv.) Ricken",
      display_name: "**__Tricholoma__** **__caligatum__** (Viv.) Ricken"
    )

    location = locations(:burbank)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      sciname: unqualified_name.text_name,
      scientificNameAuthorship: unqualified_name.author,
      identificationQualifier: "group sensu Besette et al."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_standard_provisional
    name = Name.create!(
      user: rolf,
      rank: "Species",
      text_name: "Geoglossum sp. 'MI01'",
      author: "",
      search_name: "Geoglossum sp. 'MI01'",
      display_name: "**__Geoglossum__** sp. **__'MI01'__**"
    )
    location = locations(:burbank)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      sciname: "Geoglossum sp. 'MI01'",
      identificationQualifier: "nom. prov."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_explicit_provisional
    name = Name.create!(
      user: rolf,
      rank: "Species",
      text_name: "Gymnopus bakerensis",
      author: "(A.H. Sm.) auct. comb. prov.",
      search_name: "Gymnopus bakerensis (A.H. Sm.) auct. comb. prov.",
      display_name: "__Gymnopus__ __bakerensis__ (A.H. Sm.) auct. comb. prov."
    )
    location = locations(:burbank)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      sciname: "Gymnopus bakerensis",
      scientificNameAuthorship: "",
      identificationQualifier: "(A.H. Sm.) auct. comb. prov."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_standard_provisional_crypt
    name = Name.create!(
      user: rolf,
      rank: "Species",
      text_name: "Agaricus sp. 'IN01'",
      author: "S.D. Russell crypt. temp.",
      search_name: "Agaricus sp. 'IN01' S.D. Russell crypt. temp.",
      display_name: "**__Agaricus__** sp. **__'IN01'__** " \
                    "S.D. Russell crypt. temp."
    )
    location = locations(:burbank)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      sciname: "Agaricus sp. 'IN01'",
      scientificNameAuthorship: "",
      identificationQualifier: "S.D. Russell crypt. temp."
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_identification_qualifier_sensu_non_stricto
    name = names(:coprinus_sensu_lato)
    location = locations(:burbank)
    obs = Observation.create!(user: rolf, when: Time.zone.now,
                              location: location, where: location.name,
                              name: name)

    expect = hashed_expect(obs).merge(
      scientificNameAuthorship: names(:coprinus).author,
      identificationQualifier: "sensu lato"
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_coordinate_uncertainty_no_lat_lng
    obs = observations(:minimal_unknown_obs)
    expect = hashed_expect(obs).merge.values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_coordinate_uncertainty_lat_lng_public
    obs = observations(:falmouth_2022_obs)

    # Obs has lat/lng & they are public,
    # We don't know coordinate uncertainty; leave it blank.
    expect = hashed_expect(obs).merge(
      decimalLatitude: obs.lat.to_s,
      decimalLongitude: obs.lng.to_s,
      coordinateUncertaintyInMeters: ""
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def test_mycoportal_coordinate_uncertainty_lat_lng_hidden
    obs = observations(:trusted_hidden)
    loc = obs.location

    # obs lat/lng is in the NE quadrant of loc; so SE corner is the furthest
    uncertainty = Haversine.distance(obs.lat, obs.lng, loc.south, loc.west).
                  to_meters.round.to_s

    # public lat/lng is the loc center because obs coordinates are hidden.
    expect = hashed_expect(obs).merge(
      decimalLatitude: loc.center_lat.round(4).to_s,
      decimalLongitude: loc.center_lng.round(4).to_s,
      minimumElevationInMeters: obs.alt.to_s,
      maximumElevationInMeters: obs.alt.to_s,
      coordinateUncertaintyInMeters: uncertainty
    ).values

    do_tsv_test(Report::Mycoportal, obs, expect, &:id)
  end

  def hashed_expect(obs)
    obs_location = obs.location
    obs_when = obs.when
    obs_where = obs.where
    default_uncertainty = # for obss without lat/lng, in N hemisphere
      Haversine.distance(obs_location.center_lat, obs_location.center_lng,
                         obs_location.south, obs_location.east).
      to_meters.round.to_s
    hsh = {
      dbpk: obs.id.to_s,
      basisOfRecord: "HumanObservation",
      catalogNumber: "MUOB #{obs.id}",
      sciname: obs.text_name,
      scientificNameAuthorship: obs.name.author,
      identificationQualifier: "",
      recordedBy: obs.user.legal_name,
      recordNumber: obs.collection_numbers.first&.number || "",
      eventDate: obs_when.strftime("%Y-%m-%d"),
      substrate: "",
      occurrenceRemarks: obs.notes[:Other] || "",
      associatedTaxa: "",
      verbatimAttributes: verbatim_atttributes(obs),
      # where is assumed to have just city, state/province, country
      country: obs_where.split.last,
      stateProvince: obs_where.split[-2]&.delete_suffix(",") || "",
      county: "",
      locality: obs_where.split[-3]&.delete_suffix(",") || "",
      decimalLatitude: obs_location.center_lat.to_s,
      decimalLongitude: obs_location.center_lng.to_s,
      coordinateUncertaintyInMeters: default_uncertainty,
      # if low/high are nil, value must be empty string, not zero
      minimumElevationInMeters: obs_location.low&.to_i.to_s,
      maximumElevationInMeters: obs_location.high&.to_i.to_s,
      disposition: "",
      dateLastModified: "#{obs.updated_at.api_time} UTC"
    }
    # Include this key/value only if there are images.
    hsh[:imageUrls] = expected_image_urls(obs) if obs.images.any?
    hsh
  end

  def verbatim_atttributes(obs)
    "<a href='https://mushroomobserver.org/#{obs.id}' " \
    "target='_blank' style='color: blue;'>" \
    "Original observation ##{obs.id} (Mushroom Observer)" \
    "</a>"
  end

  def expected_image_urls(obs)
    obs.images.map do |img|
      "https://mushroomobserver.org/images/orig/#{img.id}.jpg"
    end.join(" ")
  end

  def test_rounding_of_latitudes_etc
    row = Report::Row.new(vals = [])
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
    row = Report::Row.new(vals = [])
    vals[9] = { Observation.other_notes_key => " abc  def " }.to_yaml
    assert_equal("abc  def", row.obs_notes)
  end

  def test_split_date
    row = Report::Row.new(vals = [])
    vals[1] = "2017-01-03"
    assert_equal("2017", row.year)
    assert_equal("1", row.month)
    assert_equal("3", row.day)
  end

  def test_loc_name_sci
    row = Report::Row.new(vals = [])
    vals[19] = "Park, Random, Some, Alameda Co., California, USA"
    assert_equal("USA, California, Alameda Co., Some, Random, Park",
                 row.loc_name_sci)
  end

  def test_split_location
    row = Report::Row.new(vals = [])
    vals[19] = "Park, Random, Some, Alameda Co., California, USA"
    assert_equal("USA", row.country)
    assert_equal("California", row.state)
    assert_equal("Alameda", row.county)
    assert_equal("Some, Random, Park", row.locality)
    assert_equal("Alameda Co., Some, Random, Park", row.locality_with_county)

    row = Report::Row.new(vals = [])
    vals[19] = "Big Branch, Saint Tammany Parish, Louisiana, USA"
    assert_equal("USA", row.country)
    assert_equal("Louisiana", row.state)
    assert_equal("Saint Tammany", row.county)
    assert_equal("Big Branch", row.locality)
    assert_equal("Saint Tammany Parish, Big Branch", row.locality_with_county)

    row = Report::Row.new(vals = [])
    vals[19] = "Central Park, Los Angeles, California, USA"
    assert_equal("USA", row.country)
    assert_equal("California", row.state)
    assert_nil(row.county)
    assert_equal("Los Angeles, Central Park", row.locality)
    assert_equal("Los Angeles, Central Park", row.locality_with_county)
  end

  def test_split_name
    do_split_test("Fungi", "Bartl.", "Kingdom", genus: "Fungi")
    do_split_test("Agaricus", "L.", "Genus", genus: "Agaricus")
    do_split_test("Rhizocarpon geographicum group", "", "Group",
                  genus: "Rhizocarpon",
                  species: "geographicum group")
    do_split_test("Rhizocarpon geographicum group", "sensu MO", "Group",
                  genus: "Rhizocarpon",
                  species: "geographicum group",
                  species_author: "sensu MO")
    do_split_test("Rhizocarpon geographicum", "", "Species",
                  genus: "Rhizocarpon",
                  species: "geographicum")
    do_split_test("Rhizocarpon geographicum", "(L.) DC.", "Species",
                  genus: "Rhizocarpon",
                  species: "geographicum",
                  species_author: "(L.) DC.")
    do_split_test("Some thing ssp. else", "", "Subspecies",
                  genus: "Some",
                  species: "thing",
                  subspecies: "else")
    do_split_test("Some thing ssp. else", "Seuss", "Subspecies",
                  genus: "Some",
                  species: "thing",
                  subspecies: "else",
                  subspecies_author: "Seuss")
    do_split_test("Some thing var. else", "Seuss", "Variety",
                  genus: "Some",
                  species: "thing",
                  variety: "else",
                  variety_author: "Seuss")
    do_split_test("Some thing f. else", "Seuss", "Form",
                  genus: "Some",
                  species: "thing",
                  form: "else",
                  form_author: "Seuss")
    do_split_test("Some thing ssp. else var. or f. other cfr.", "Seuss", "Form",
                  genus: "Some",
                  species: "thing",
                  subspecies: "else",
                  variety: "or",
                  form: "other",
                  form_author: "Seuss",
                  cf: "cf.")
  end

  def test_ascii_encoding
    query = Query.lookup(:Observation)
    report = Report::Raw.new(query: query)
    report.encoding = "ASCII"
    body = report.body
    assert_not_empty(body)
  end

  def test_utf_16_encoding
    query = Query.lookup(:Observation)
    report = Report::Raw.new(query: query)
    report.encoding = "UTF-16"
    body = report.body
    assert_not_empty(body)
  end

  def test_project_tweaker_report
    obs = observations(:trusted_hidden)
    query = Query.lookup(:Observation)
    report_type = Report::Raw
    body = report_body(report_type, query)
    table = CSV.parse(body, col_sep: report_type.separator)
    idx = query.results.sort_by(&:id).index(obs)
    assert_nil(table[idx + 1][LAT_INDEX])
    assert_nil(table[idx + 1][LONG_INDEX])

    # user must be project admin for query to work.
    body = report_body(report_type, query, user: users(:roy))
    table = CSV.parse(body, col_sep: report_type.separator)
    idx = query.results.sort_by(&:id).index(obs)
    assert_equal(obs.lat.to_s, table[idx + 1][LAT_INDEX])
    assert_equal(obs.lng.to_s, table[idx + 1][LONG_INDEX])
  end

  private

  def do_csv_test(report_type, obs, expect, user: nil, &block)
    query = Query.lookup(:Observation)
    body = report_body(report_type, query, user:)
    table = CSV.parse(body, col_sep: report_type.separator)
    assert_equal(query.num_results + 1, table.count)
    idx = query.results.sort_by(&block).index(obs)
    assert_equal(expect, table[idx + 1])
  end

  def report_body(report_type, query, user: nil)
    report = report_type.new(query:, user:)
    assert_not_empty(report.filename)
    body = report.body
    assert_not_empty(body)
    body
  end

  def do_tsv_test(report_type, obs, expect, &block)
    query = Query.lookup(:Observation)
    body = report_body(report_type, query)
    rows = body.split("\n")
    assert_equal(query.num_results + 1, rows.length)
    idx = query.results.sort_by(&block).index(obs)
    assert_equal(expect, rows[idx + 1].split("\t"))
  end

  def do_zip_test(report_type, expect)
    body = report_body(report_type, Query.lookup(:Observation))
    zio = Zip::InputStream.new(StringIO.new(body))
    contents = []
    while (entry = zio.get_next_entry)
      contents << entry.name
    end
    assert_equal(expect, contents)
  end

  def build_taxa_report
    query = Query.lookup(:Observation)
    observations = Report::Darwin::Observations.new(query: query)
    return if observations.body.empty?

    report_type = Report::Darwin::Taxa
    report_type.new(query: query, observations: observations)
  end

  def do_split_test(name, author, rank, expect)
    row = Report::Row.new(vals = [])
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
end
