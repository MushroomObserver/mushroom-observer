# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2Test < UnitTestCase
  include API2Extensions

  # --------------------
  #  :section: Parsers
  # --------------------

  def test_parse_boolean
    assert_parse(:boolean, nil, nil)
    assert_parse(:boolean, true, nil, default: true)
    assert_parse(:boolean, false, "0")
    assert_parse(:boolean, false, "0", default: true)
    assert_parse(:boolean, false, "no")
    assert_parse(:boolean, false, "NO")
    assert_parse(:boolean, false, "false")
    assert_parse(:boolean, false, "False")
    assert_parse(:boolean, true, "1")
    assert_parse(:boolean, true, "yes")
    assert_parse(:boolean, true, "true")
    assert_parse(:boolean, API2::BadParameterValue, "foo")
    assert_parse_a(:boolean, nil, nil)
    assert_parse_a(:boolean, [], nil, default: [])
    assert_parse_a(:boolean, [true], "1")
    assert_parse_a(:boolean, [true, false], "1,0")
  end

  def test_parse_enum
    limit = [:one, :two, :three, :four, :five]
    assert_parse(:enum, nil, nil, limit: limit)
    assert_parse(:enum, :three, nil, limit: limit, default: :three)
    assert_parse(:enum, :two, "two", limit: limit)
    assert_parse(:enum, :two, "Two", limit: limit)
    assert_parse(:enum, API2::BadLimitedParameterValue, "", limit: limit)
    assert_parse(:enum, API2::BadLimitedParameterValue, "Ten", limit: limit)
    assert_parse_a(:enum, nil, nil, limit: limit)
    assert_parse_a(:enum, [:one], "one", limit: limit)
    assert_parse_a(:enum, [:one, :two, :three], "one,two,three", limit: limit)
    assert_parse_r(:enum, nil, nil, limit: limit)
    assert_parse_r(:enum, :four, "four", limit: limit)
    assert_parse_r(:enum, aor(:one, :four), "four-one", limit: limit)
  end

  def test_parse_string
    assert_parse(:string, nil, nil)
    assert_parse(:string, "hello", nil, default: "hello")
    assert_parse(:string, "foo", "foo", default: "hello")
    assert_parse(:string, "foo", " foo\n", default: "hello")
    assert_parse(:string, "", "", default: "hello")
    assert_parse(:string, "abcd", "abcd", limit: 4)
    assert_parse(:string, API2::StringTooLong, "abcde", limit: 4)
    assert_parse_a(:string, nil, nil)
    assert_parse_a(:string, ["foo"], "foo")
    assert_parse_a(:string, %w[foo bar], "foo,bar", limit: 4)
    assert_parse_a(:string, API2::StringTooLong, "foo,abcde", limit: 4)
  end

  def test_parse_integer
    exception = API2::BadLimitedParameterValue
    assert_parse(:integer, nil, nil)
    assert_parse(:integer, 42, nil, default: 42)
    assert_parse(:integer, 1, "1")
    assert_parse(:integer, 0, " 0 ")
    assert_parse(:integer, -13, "-13")
    assert_parse_a(:integer, nil, nil)
    assert_parse_a(:integer, [1], "1")
    assert_parse_a(:integer, [3, -1, 4, -159], "3,-1,4,-159")
    assert_parse_a(:integer, [1, 13], "1,13", limit: 1..13)
    assert_parse_a(:integer, exception, "0,13", limit: 1..13)
    assert_parse_a(:integer, exception, "1,14", limit: 1..13)
    assert_parse_r(:integer, aor(1, 13), "1-13", limit: 1..13)
    assert_parse_r(:integer, exception, "0-13", limit: 1..13)
    assert_parse_r(:integer, exception, "1-14", limit: 1..13)
    assert_parse_rs(:integer, nil, nil, limit: 1..13)
    assert_parse_rs(:integer, [aor(1, 4), aor(6, 9)], "1-4,6-9", limit: 1..13)
    assert_parse_rs(:integer, [1, 4, aor(6, 9)], "1,4,6-9", limit: 1..13)
  end

  def test_parse_float
    assert_parse(:float, nil, nil)
    assert_parse(:float, -2.71828, nil, default: -2.71828)
    assert_parse(:float, 0, "0", default: -2.71828)
    assert_parse(:float, 4, "4")
    assert_parse(:float, -4, "-4")
    assert_parse(:float, 4, "4.0")
    assert_parse(:float, -4, "-4.0")
    assert_parse(:float, 0, ".0")
    assert_parse(:float, 0.123, ".123")
    assert_parse(:float, -0.123, "-.123")
    assert_parse(:float, 123.123, "123.123")
    assert_parse(:float, -123.123, "-123.123")
    assert_parse_a(:float, nil, nil)
    assert_parse_a(:float, [1.2, 3.4], " 1.20, 3.40 ")
    assert_parse_rs(:float, [aor(1, 2), 4, 5], "1-2,4,5")
    assert_parse(:float, API2::BadParameterValue, "")
    assert_parse(:float, API2::BadParameterValue, "one")
    assert_parse(:float, API2::BadParameterValue, "+1e5")
  end

  def test_parse_date
    assert_parse(:date, nil, nil)
    assert_parse(:date, date("2012-06-25"), nil,
                 default: date("2012-06-25"))
    assert_parse(:date, date("2012-06-26"), "20120626")
    assert_parse(:date, date("2012-06-26"), "2012-06-26")
    assert_parse(:date, date("2012-06-26"), "2012/06/26")
    assert_parse(:date, date("2012-06-07"), "2012-6-7")
    assert_parse(:date, API2::BadParameterValue, "2012-06/7")
    assert_parse(:date, API2::BadParameterValue, "2012 6/7")
    assert_parse(:date, API2::BadParameterValue, "6/26/2012")
    assert_parse(:date, API2::BadParameterValue, "today")
  end

  def test_parse_time
    assert_parse(:time, nil, nil)
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"), nil,
                 default: api_test_time("2012-06-25 12:34:56"))
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "20120625123456")
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "2012-06-25 12:34:56")
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "2012/06/25 12:34:56")
    assert_parse(:time, api_test_time("2012-06-05 02:04:06"),
                 "2012/6/5 2:4:6")
    assert_parse(:time, API2::BadParameterValue, "20120625")
    assert_parse(:time, API2::BadParameterValue, "201206251234567")
    assert_parse(:time, API2::BadParameterValue, "2012/06/25 103456")
    assert_parse(:time, API2::BadParameterValue, "2012-06/25 10:34:56")
    assert_parse(:time, API2::BadParameterValue, "2012/06/25 10:34:56am")
  end

  def test_parse_date_range
    assert_parse_r(:date, nil, nil)
    assert_parse_r(:date, "blah", nil, default: "blah")
    assert_parse_dr("2012-06-26", "2012-06-26", "20120626")
    assert_parse_dr("2012-06-26", "2012-06-26", "2012-06-26")
    assert_parse_dr("2012-06-26", "2012-06-26", "2012/06/26")
    assert_parse_dr("2012-06-07", "2012-06-07", "2012-6-7")
    assert_parse_r(:date, API2::BadParameterValue, "2012-06/7")
    assert_parse_r(:date, API2::BadParameterValue, "2012 6/7")
    assert_parse_r(:date, API2::BadParameterValue, "6/26/2012")
    assert_parse_r(:date, API2::BadParameterValue, "today")
    assert_parse_dr("2012-06-01", "2012-06-30", "201206")
    assert_parse_dr("2012-06-01", "2012-06-30", "2012-6")
    assert_parse_dr("2012-06-01", "2012-06-30", "2012/06")
    assert_parse_dr("2012-01-01", "2012-12-31", "2012")
    assert_parse_r(:date, aor(6, 6), "6")
    assert_parse_r(:date, aor(613, 613), "6/13")
    assert_parse_dr("2011-05-13", "2012-06-15", "20110513-20120615")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011-05-13-2012-06-15")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011-5-13-2012-6-15")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011/05/13 - 2012/06/15")
    assert_parse_dr("2011-05-01", "2012-06-30", "201105-201206")
    assert_parse_dr("2011-05-01", "2012-06-30", "2011-5-2012-6")
    assert_parse_dr("2011-05-01", "2012-06-30", "2011/05 - 2012/06")
    assert_parse_dr("2011-01-01", "2012-12-31", "2011-2012")
    assert_parse_r(:date, aor(2, 5), "2-5")
    assert_parse_r(:date, aor(10, 3), "10-3")
    assert_parse_r(:date, aor(612, 623), "0612-0623")
    assert_parse_r(:date, aor(1225, 101), "12-25-1-1")
  end

  def assert_parse_dr(from, to, str)
    from = date(from)
    to   = date(to)
    assert_parse_r(:date, aor(from, to), str)
  end

  # rubocop:disable Layout/LineLength
  def test_parse_time_range
    assert_parse_r(:time, nil, nil)
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "20120625123456")
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "2012-06-25 12:34:56")
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "2012/06/25 12:34:56")
    assert_parse_tr("2012-06-05 02:04:06", "2012-06-05 02:04:06", "2012/6/5 2:4:6")
    assert_parse_r(:time, API2::BadParameterValue, "201206251234567")
    assert_parse_r(:time, API2::BadParameterValue, "2012/06/25 103456")
    assert_parse_r(:time, API2::BadParameterValue, "2012-06/25 10:34:56")
    assert_parse_r(:time, API2::BadParameterValue, "2012/06/25 10:34:56am")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "201102240203")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "2011-2-24 2:3")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "2011/02/24 02:03")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011022402")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011-2-24 2")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011/02/24 02")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "20110224")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "2011-2-24")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "2011/02/24")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "201102")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "2011-2")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "2011/02")
    assert_parse_tr("2011-01-01 00:00:00", "2011-12-31 23:59:59", "2011")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "20110524020304-20120625030405")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "2011-5-24 2:3:4-2012-6-25 3:4:5")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "2011/05/24 02:03:04 - 2012/06/25 03:04:05")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "201105240203-201206250304")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "2011-5-24 2:3-2012-6-25 3:4")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "2011/05/24 02:03 - 2012/06/25 03:04")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011052402-2012062503")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011-5-24 2-2012-6-25 3")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011/05/24 02 - 2012/06/25 03")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "20110524-20120625")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "2011-5-24-2012-6-25")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "2011/05/24 - 2012/06/25")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "201105-201206")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "2011-5-2012-6")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "2011/05 - 2012/06")
    assert_parse_tr("2011-01-01 00:00:00", "2012-12-31 23:59:59", "2011-2012")
    assert_parse_tr("2011-01-01 00:00:00", "2012-12-31 23:59:59", "2011 - 2012")
  end
  # rubocop:enable Layout/LineLength

  def assert_parse_tr(from, to, str)
    from = api_test_time(from)
    to   = api_test_time(to)
    ordered_range = aor(from, to)
    assert_parse_r(:time, ordered_range, str)
  end

  def test_parse_latitude
    assert_parse(:latitude, nil, nil)
    assert_parse(:latitude, 45, nil, default: 45)
    assert_parse(:latitude, 4, "4")
    assert_parse(:latitude, -4, "-4")
    assert_parse(:latitude, 4.1235, "4.1234567")
    assert_parse(:latitude, -4.1235, "-4.1234567")
    assert_parse(:latitude, -4.1235, "4.1234567S")
    assert_parse(:latitude, 12.5822, '12°34\'56"N')
    assert_parse(:latitude, 12.5760, "12 34.56 N")
    assert_parse(:latitude, -12.0094, "12deg 34sec S")
    assert_parse(:latitude, API2::BadParameterValue, "12 34.56 E")
    assert_parse(:latitude, API2::BadParameterValue, "12 degrees 34.56 minutes")
    assert_parse(:latitude, API2::BadParameterValue, "12.56s")
    assert_parse(:latitude, 90.0000, "90d 0s N")
    assert_parse(:latitude, -90.0000, "90d 0s S")
    assert_parse(:latitude, API2::BadParameterValue, "90d 1s N")
    assert_parse(:latitude, API2::BadParameterValue, "90d 1s S")
    assert_parse_a(:latitude, nil, nil)
    assert_parse_a(:latitude, [1.2, 3.4], "1.2,3.4")
    assert_parse_r(:latitude, nil, nil)
    assert_parse_r(:latitude, aor(-12, 34), "12S-34N")
    assert_parse_rs(:latitude, [aor(-12, 34), 6, 7], "12S-34N,6,7")
  end

  def test_parse_longitude
    assert_parse(:longitude, nil, nil)
    assert_parse(:longitude, 45, nil, default: 45)
    assert_parse(:longitude, 4, "4")
    assert_parse(:longitude, -4, "-4")
    assert_parse(:longitude, 4.1235, "4.1234567")
    assert_parse(:longitude, -4.1235, "-4.1234567")
    assert_parse(:longitude, -4.1235, "4.1234567W")
    assert_parse(:longitude, 12.5822, '12°34\'56"E')
    assert_parse(:longitude, 12.5760, "12 34.56 E")
    assert_parse(:longitude, -12.0094, "12deg 34sec W")
    assert_parse(:longitude, API2::BadParameterValue, "12 34.56 S")
    assert_parse(:longitude, API2::BadParameterValue,
                 "12 degrees 34.56 minutes")
    assert_parse(:longitude, API2::BadParameterValue, "12.56e")
    assert_parse(:longitude, 180.0000, "180d 0s E")
    assert_parse(:longitude, -180.0000, "180d 0s W")
    assert_parse(:longitude, API2::BadParameterValue, "180d 1s E")
    assert_parse(:longitude, API2::BadParameterValue, "180d 1s W")
    assert_parse_a(:longitude, nil, nil)
    assert_parse_a(:longitude, [1.2, 3.4], "1.2,3.4")
    assert_parse_r(:longitude, nil, nil)
    assert_parse_r(:longitude, aor(-12, 34), "12W-34E")
    assert_parse_rs(:longitude, [aor(-12, 34), 6, 7], "12W-34E,6,7")
  end

  def test_parse_altitude
    assert_parse(:altitude, nil, nil)
    assert_parse(:altitude, 123, nil, default: 123)
    assert_parse(:altitude, 123, "123")
    assert_parse(:altitude, 123, "123 m")
    assert_parse(:altitude, 123, "403 ft")
    assert_parse(:altitude, 123, "403'")
    assert_parse(:altitude, API2::BadParameterValue, "sealevel")
    assert_parse(:altitude, API2::BadParameterValue, "123 FT")
    assert_parse_a(:altitude, nil, nil)
    assert_parse_a(:altitude, [123], "123")
    assert_parse_a(:altitude, [123, 456], "123,456m")
    assert_parse_r(:altitude, nil, nil)
    assert_parse_r(:altitude, aor(12, 34), "12-34")
    assert_parse_r(:altitude, aor(54, 76), "54-76")
    assert_parse_rs(:altitude, nil, nil)
    assert_parse_rs(:altitude, [aor(54, 76), 3, 2], "54-76,3,2")
  end

  def test_parse_external_site
    site = external_sites(:mycoportal)
    assert_parse(:external_site, nil, nil)
    assert_parse(:external_site, site, nil, default: site)
    assert_parse(:external_site, site, site.id)
    assert_parse(:external_site, site, site.name)
    assert_parse(:external_site, API2::BadParameterValue, "")
    assert_parse(:external_site, API2::ObjectNotFoundByString, "name")
    assert_parse(:external_site, API2::ObjectNotFoundById, "12345")
  end

  def test_parse_image
    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    assert_parse(:image, nil, nil)
    assert_parse(:image, img1, nil, default: img1)
    assert_parse(:image, img1, img1.id)
    assert_parse_a(:image, [img2, img1], "#{img2.id},#{img1.id}")
    assert_parse_r(:image, aor(img2, img1), "#{img2.id}-#{img1.id}")
    assert_parse(:image, API2::BadParameterValue, "")
    assert_parse(:image, API2::BadParameterValue, "name")
    assert_parse(:image, API2::ObjectNotFoundById, "12345")
  end

  def test_parse_license
    lic1 = licenses(:ccnc25)
    lic2 = licenses(:ccnc30)
    assert_parse(:license, nil, nil)
    assert_parse(:license, lic2, nil, default: lic2)
    assert_parse(:license, lic2, lic2.id)
    assert_parse_a(:license, [lic2, lic1], "#{lic2.id},#{lic1.id}")
    assert_parse_r(:license, aor(lic2, lic1), "#{lic2.id}-#{lic1.id}")
    assert_parse(:license, API2::BadParameterValue, "")
    assert_parse(:license, API2::BadParameterValue, "name")
    assert_parse(:license, API2::ObjectNotFoundById, "12345")
  end

  def test_parse_location
    burbank = locations(:burbank)
    gualala = locations(:gualala)
    assert_parse(:location, nil, nil)
    assert_parse(:location, gualala, nil, default: gualala)
    assert_parse(:location, gualala, gualala.id)
    assert_parse_a(:location, [gualala, burbank], "#{gualala.id},#{burbank.id}")
    assert_parse_r(:location, aor(gualala, burbank),
                   "#{gualala.id}-#{burbank.id}")
    assert_parse(:location, API2::BadParameterValue, "")
    assert_parse(:location, API2::ObjectNotFoundByString, "name")
    assert_parse(:location, API2::ObjectNotFoundById, "12345")
    assert_parse(:location, burbank, burbank.name)
    assert_parse(:location, burbank, burbank.scientific_name)
  end

  def test_parse_place_name
    burbank = locations(:burbank)
    gualala = locations(:gualala)
    assert_parse(:place_name, nil, nil)
    assert_parse(:place_name, gualala.name, nil, default: gualala.name)
    assert_parse(:place_name, gualala.name, gualala.name)
    assert_parse(:place_name, API2::BadParameterValue, "")
    assert_parse(:place_name, "name", "name")
    assert_parse(:place_name, API2::ObjectNotFoundById, "12345")
    assert_parse(:place_name, burbank.name, burbank.name)
    assert_parse(:place_name, burbank.name, burbank.scientific_name)
  end

  def test_parse_name
    m_rhacodes = names(:macrolepiota_rhacodes)
    a_campestris = names(:agaricus_campestras)
    assert_parse(:name, nil, nil)
    assert_parse(:name, a_campestris, nil, default: a_campestris)
    assert_parse(:name, a_campestris, a_campestris.id)
    assert_parse(:name, API2::BadParameterValue, "")
    assert_parse(:name, API2::ObjectNotFoundById, "12345")
    assert_parse(:name, API2::ObjectNotFoundByString, "Bogus name")
    assert_parse(:name, API2::NameDoesntParse, "yellow mushroom")
    assert_parse(:name, API2::AmbiguousName, "Amanita baccata")
    assert_parse(:name, m_rhacodes, "Macrolepiota rhacodes")
    assert_parse(:name, m_rhacodes, "Macrolepiota rhacodes (Vittad.) Singer")
    assert_parse_a(:name, [a_campestris, m_rhacodes],
                   "#{a_campestris.id},#{m_rhacodes.id}")
    assert_parse_r(:name, aor(a_campestris, m_rhacodes),
                   "#{a_campestris.id}-#{m_rhacodes.id}")
  end

  def test_parse_observation
    a_campestrus_obs = observations(:agaricus_campestrus_obs)
    unknown_lat_lon_obs = observations(:unknown_with_lat_lng)
    assert_parse(:observation, nil, nil)
    assert_parse(:observation, a_campestrus_obs, nil, default: a_campestrus_obs)
    assert_parse(:observation, a_campestrus_obs, a_campestrus_obs.id)
    assert_parse_a(:observation, [unknown_lat_lon_obs, a_campestrus_obs],
                   "#{unknown_lat_lon_obs.id},#{a_campestrus_obs.id}")
    assert_parse_r(:observation, aor(unknown_lat_lon_obs, a_campestrus_obs),
                   "#{unknown_lat_lon_obs.id}-#{a_campestrus_obs.id}")
    assert_parse(:observation, API2::BadParameterValue, "")
    assert_parse(:observation, API2::BadParameterValue, "name")
    assert_parse(:observation, API2::ObjectNotFoundById, "12345")
  end

  def test_parse_project
    eol_proj = projects(:eol_project)
    bolete_proj = projects(:bolete_project)
    assert_parse(:project, nil, nil)
    assert_parse(:project, bolete_proj, nil, default: bolete_proj)
    assert_parse(:project, bolete_proj, bolete_proj.id)
    assert_parse_a(:project, [bolete_proj, eol_proj],
                   "#{bolete_proj.id},#{eol_proj.id}")
    assert_parse_r(:project, aor(bolete_proj, eol_proj),
                   "#{bolete_proj.id}-#{eol_proj.id}")
    assert_parse(:project, API2::BadParameterValue, "")
    assert_parse(:project, API2::ObjectNotFoundByString, "name")
    assert_parse(:project, API2::ObjectNotFoundById, "12345")
    assert_parse(:project, eol_proj, eol_proj.title)
  end

  def test_parse_species_list
    first_list = species_lists(:first_species_list)
    another_list = species_lists(:another_species_list)
    assert_parse(:species_list, nil, nil)
    assert_parse(:species_list, another_list, nil, default: another_list)
    assert_parse(:species_list, another_list, another_list.id)
    assert_parse_a(:species_list, [another_list, first_list],
                   "#{another_list.id},#{first_list.id}")
    assert_parse_r(:species_list, aor(another_list, first_list),
                   "#{another_list.id}-#{first_list.id}")
    assert_parse(:species_list, API2::BadParameterValue, "")
    assert_parse(:species_list, API2::ObjectNotFoundByString, "name")
    assert_parse(:species_list, API2::ObjectNotFoundById, "12345")
    assert_parse(:species_list, first_list, first_list.title)
  end

  def test_parse_user
    assert_parse(:user, nil, nil)
    assert_parse(:user, mary, nil, default: mary)
    assert_parse(:user, mary, mary.id)
    assert_parse_a(:user, [mary, rolf], "#{mary.id},#{rolf.id}")
    assert_parse_r(:user, aor(mary, rolf), "#{mary.id}-#{rolf.id}")
    assert_parse(:user, API2::BadParameterValue, "")
    assert_parse(:user, API2::ObjectNotFoundByString, "name")
    assert_parse(:user, API2::ObjectNotFoundById, "12345")
    assert_parse(:user, rolf, rolf.login)
    assert_parse(:user, rolf, rolf.name)
    assert_parse(:user, rolf, rolf.email)
  end

  def test_parse_object
    limit = [Name, Observation, SpeciesList]
    obs = observations(:unknown_with_lat_lng)
    nam = names(:agaricus_campestras)
    list = species_lists(:another_species_list)
    assert_parse(:object, nil, nil, limit: limit)
    assert_parse(:object, obs, nil, default: obs, limit: limit)
    assert_parse(:object, obs, "observation #{obs.id}", limit: limit)
    assert_parse(:object, nam, "name #{nam.id}", limit: limit)
    assert_parse(:object, list, "species list #{list.id}", limit: limit)
    assert_parse(:object, list, "species_list #{list.id}", limit: limit)
    assert_parse(:object, list, "Species List #{list.id}", limit: limit)
    assert_parse(:object, API2::BadParameterValue, "", limit: limit)
    assert_parse(:object, API2::BadParameterValue, "1", limit: limit)
    assert_parse(:object, API2::BadParameterValue, "bogus", limit: limit)
    assert_parse(:object, API2::BadLimitedParameterValue, "bogus 1",
                 limit: limit)
    assert_parse(:object, API2::BadLimitedParameterValue,
                 "license #{licenses(:ccnc25).id}", limit: limit)
    assert_parse(:object, API2::ObjectNotFoundById, "name 12345",
                 limit: limit)
    assert_parse_a(:object, [obs, nam],
                   "observation #{obs.id}, name #{nam.id}", limit: limit)
  end

  def test_parse_email
    assert_parse(:email, API2::BadParameterValue, "blah blah blah")
    assert_parse(:email, "simple@email.com", "simple@email.com")
    assert_parse(:email, "Ab3!#$%&'*+/=?^_'{|}~-@crazy-email.123",
                 "Ab3!#$%&'*+/=?^_'{|}~-@crazy-email.123")
  end

  # ---------------------------
  #  :section: Authentication
  # ---------------------------

  def test_unverified_user_rejected
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere"
    }
    User.update(rolf.id, verified: nil)
    assert_api_fail(params)
    User.update(rolf.id, verified: Time.zone.now)
    assert_api_pass(params)
  end

  def test_unverified_api_key_rejected
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere"
    }
    APIKey.update(@api_key.id, verified: nil)
    assert_api_fail(params)
    @api_key.verify!
    assert_api_pass(params)
  end

  def test_check_edit_permission
    @api      = API2.new
    @api.user = dick
    proj      = dick.projects_member.first

    img_good = proj.images.first
    img_bad  = (Image.all - proj.images - dick.images).first
    obs_good = proj.observations.first
    obs_bad  = (Observation.all - proj.observations - dick.observations).first
    spl_good = proj.species_lists.first
    spl_bad  = (SpeciesList.all - proj.species_lists - dick.species_lists).first
    assert_not_nil(img_good)
    assert_not_nil(img_bad)
    assert_not_nil(obs_good)
    assert_not_nil(obs_bad)
    assert_not_nil(spl_good)
    assert_not_nil(spl_bad)

    args = { must_have_edit_permission: true }
    assert_parse(:image, img_good, img_good.id, args)
    assert_parse(:image, API2::MustHaveEditPermission, img_bad.id, args)
    assert_parse(:observation, obs_good, obs_good.id, args)
    assert_parse(:observation, API2::MustHaveEditPermission, obs_bad.id, args)
    assert_parse(:species_list, spl_good, spl_good.id, args)
    assert_parse(:species_list, API2::MustHaveEditPermission, spl_bad.id, args)
    assert_parse(:user, dick, dick.id, args)
    assert_parse(:user, API2::MustHaveEditPermission, rolf.id, args)

    args[:limit] = [Image, Observation, SpeciesList, User]
    assert_parse(:object, img_good, "image #{img_good.id}", args)
    assert_parse(:object, API2::MustHaveEditPermission,
                 "image #{img_bad.id}", args)
    assert_parse(:object, obs_good, "observation #{obs_good.id}", args)
    assert_parse(:object, API2::MustHaveEditPermission,
                 "observation #{obs_bad.id}", args)
    assert_parse(:object, spl_good, "species list #{spl_good.id}", args)
    assert_parse(:object, API2::MustHaveEditPermission,
                 "species list #{spl_bad.id}", args)
    assert_parse(:object, dick, "user #{dick.id}", args)
    assert_parse(:object, API2::MustHaveEditPermission, "user #{rolf.id}", args)
  end

  def test_check_project_membership
    @api   = API2.new
    proj   = projects(:eol_project)
    admin  = proj.admin_group.users.first
    member = (proj.user_group.users - proj.admin_group.users).first
    other  = (User.all - proj.admin_group.users - proj.user_group.users).first
    assert_not_nil(admin)
    assert_not_nil(member)
    assert_not_nil(other)

    @api.user = admin
    assert_parse(:project, proj, proj.id, must_be_admin: true)
    assert_parse(:project, proj, proj.id, must_be_member: true)

    @api.user = member
    assert_parse(:project, API2::MustBeAdmin, proj.id, must_be_admin: true)
    assert_parse(:project, proj, proj.id, must_be_member: true)

    @api.user = other
    assert_parse(:project, API2::MustBeAdmin, proj.id, must_be_admin: true)
    assert_parse(:project, API2::MustBeMember, proj.id, must_be_member: true)
  end

  # --------------------------
  #  :section: Help Messages
  # --------------------------

  def test_deprecation
    api = API2.execute(method: :get, action: :image, help: :me)
    assert_match(/created_at/, api.errors.first.to_s)
    assert_no_match(/synonyms_of|children_of/, api.errors.first.to_s)
  end

  def test_help
    do_help_test(:get, :api_key, fail: true)
    do_help_test(:post, :api_key)
    do_help_test(:patch, :api_key, fail: true)
    do_help_test(:delete, :api_key, fail: true)

    do_help_test(:get, :comment)
    do_help_test(:post, :comment)
    do_help_test(:patch, :comment)
    do_help_test(:delete, :comment)

    do_help_test(:get, :external_link)
    do_help_test(:post, :external_link)
    do_help_test(:patch, :external_link)
    do_help_test(:delete, :external_link)

    do_help_test(:get, :external_site)
    do_help_test(:post, :external_site, fail: true)
    do_help_test(:patch, :external_site, fail: true)
    do_help_test(:delete, :external_site, fail: true)

    do_help_test(:get, :herbarium)
    do_help_test(:post, :herbarium, fail: true)
    do_help_test(:patch, :herbarium, fail: true)
    do_help_test(:delete, :herbarium, fail: true)

    do_help_test(:get, :image)
    do_help_test(:post, :image)
    do_help_test(:patch, :image)
    do_help_test(:delete, :image)

    do_help_test(:get, :location)
    do_help_test(:post, :location)
    do_help_test(:patch, :location)
    do_help_test(:delete, :location, fail: true)

    do_help_test(:get, :name)
    do_help_test(:post, :name)
    do_help_test(:patch, :name)
    do_help_test(:delete, :name, fail: true)

    do_help_test(:get, :observation)
    do_help_test(:post, :observation)
    do_help_test(:patch, :observation)
    do_help_test(:delete, :observation)

    do_help_test(:get, :project)
    do_help_test(:post, :project)
    do_help_test(:patch, :project)
    do_help_test(:delete, :project, fail: true)

    do_help_test(:get, :sequence)
    do_help_test(:post, :sequence)
    do_help_test(:patch, :sequence)
    do_help_test(:delete, :sequence)

    do_help_test(:get, :species_list)
    do_help_test(:post, :species_list)
    do_help_test(:patch, :species_list)
    do_help_test(:delete, :species_list)

    do_help_test(:get, :user)
    do_help_test(:post, :user)
    do_help_test(:patch, :user)
    do_help_test(:delete, :user)
  end

  def do_help_test(method, action, fail: false)
    params = {
      method: method,
      action: action,
      help: :me
    }
    params[:api_key] = @api_key.key if method != :get
    api = API2.execute(params)
    others = api.errors.reject { |e| e.instance_of?(API2::HelpMessage) }
    assert_equal(1, api.errors.length, others.map(&:to_s))
    if fail
      assert_equal("API2::NoMethodForAction", api.errors.first.class.name)
    else
      assert_equal("API2::HelpMessage", api.errors.first.class.name)
    end
  end
end
