# frozen_string_literal: true

require("test_helper")

class ObservationsControllerCreateTest < FunctionalTestCase
  include ActiveJob::TestHelper

  tests ObservationsController

  def modified_generic_params(params, user)
    params[:observation] = sample_obs_fields.merge(params[:observation] || {})
    params[:naming][:vote] = { value: "3" }.merge(params[:naming][:vote] || {})
    params[:collection_number] =
      default_collection_number_fields.merge(params[:collection_number] || {})
    params[:herbarium_record] =
      default_herbarium_record_fields.merge(params[:herbarium_record] || {})
    params[:username] = user.login
    params
  end

  def sample_obs_fields
    { place_name: "Right Here, Massachusetts, USA",
      lat: "",
      lng: "",
      alt: "",
      "when(1i)" => "2007",
      "when(2i)" => "10",
      "when(3i)" => "31",
      specimen: "0",
      thumb_image_id: "0" }
  end

  def default_collection_number_fields
    { name: "", number: "" }
  end

  def default_herbarium_record_fields
    { herbarium_name: "", accession_number: "" }
  end

  def location_exists_or_place_name_blank(params, user)
    name = Location.user_format(user, params[:observation][:place_name])
    Location.find_by(name:) || Location.is_unknown?(name) || name.blank?
  end

  # Test constructing observations in various ways (with minimal namings)
  def generic_construct_observation(params, o_num, g_num, n_num, l_num,
                                    user = rolf)
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    l_count = Location.count
    score   = user.reload.contribution
    params  = modified_generic_params(params, user)
    post_requires_login(:create, params)

    begin
      if o_num.zero?
        assert_response(:success)
      elsif location_exists_or_place_name_blank(params, user)
        # assert_redirected_to(action: :show)
        assert_response(:redirect)
        assert_match(%r{/test.host/obs/\d+\Z}, @response.redirect_url)
      else
        assert_response(:redirect)
        # assert_redirected_to(/#{new_location_path}/)
      end
    rescue Minitest::Assertion => e
      flash = get_last_flash.to_s.dup.sub!(/^(\d)/, "")
      message = "#{e}\n" \
                "Flash messages: (level #{Regexp.last_match(1)})\n" \
                "< #{flash} >\n"
      flunk(message)
    end
    assert_equal(o_count + o_num, Observation.count, "Wrong Observation count")
    assert_equal(g_count + g_num, Naming.count, "Wrong Naming count")
    assert_equal(n_count + n_num, Name.count, "Wrong Name count")
    assert_equal(l_count + l_num, Location.count, "Wrong Location count")
    assert_equal(score + o_num + g_num * 2 + n_num * 10 + l_num * 10,
                 user.reload.contribution,
                 "Wrong User score")
    return unless o_num == 1

    assert_not_equal(
      0,
      @controller.instance_variable_get(:@observation).thumb_image_id,
      "Wrong image id"
    )
  end

  ##############################################################################

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "new" observation form.
  def test_create_new_observation
    requires_login(:new)
    assert_form_action(action: :create)
    assert_input_value(:collection_number_name,
                       users(:rolf).legal_name)
    assert_input_value(:collection_number_number, "")
    assert_input_value(:herbarium_record_herbarium_name,
                       users(:rolf).preferred_herbarium_name)
    assert_input_value(:herbarium_record_accession_number, "")
    assert_true(@response.body.include?("Albion, Mendocino Co., California"))
    assert_link_in_html(:create_observation_inat_import_link.l,
                        new_inat_import_path)
    # Naming reasons fields should be present (collapsed until name entered)
    assert_select("input[id^='naming_reasons_'][id$='_check']")

    users(:rolf).update(location_format: "scientific")
    get(:new)
    assert_true(@response.body.include?("California, Mendocino Co., Albion"))
  end

  def test_new_with_name
    login
    name = names(:coprinus_comatus)
    get(:new, params: { name: name.text_name })
    assert(@response.body.include?(name.text_name))
  end

  def test_create_log_updated_at
    params = {
      naming: { name: "", vote: { value: "" } },
      user: rolf,
      observation: { place_name: locations.first.name }
    }

    users(:rolf).login
    post_requires_login(:create, params)

    assert(Observation.last.log_updated_at.is_a?(Time),
           "Observation should have log_updated_at time")
  end

  def test_create_observation_without_scientific_name
    params = { user: rolf,
               observation: { place_name: locations.first.name } }
    fungi = names(:fungi)

    post_requires_login(:create, params)

    assert_flash_success(
      "Omitting Scientific Name should not cause flash error or warning."
    )
    assert_equal(
      fungi, Observation.last.name,
      "Observation should be id'd as `Fungi` if user omits Scientific Name."
    )
  end

  def test_create_observation_with_unrecognized_name
    text_name = "Elfin saddle"
    params = { naming: { name: text_name },
               user: rolf,
               observation: { place_name: locations.first.name } }
    post_requires_login(:create, params)

    assert_select("div[id='name_messages']",
                  /MO does not recognize the name.*#{text_name}/)
  end

  def test_construct_observation_approved_place_name
    where = "Albion, California, USA"
    generic_construct_observation(
      { observation: { place_name: where },
        naming: { name: "Coprinus comatus" },
        approved_place_name: "" },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert_equal(where, obs.place_name)
    assert_equal("mo_website", obs.source)
  end

  def test_create_observation_with_field_slip
    generic_construct_observation(
      { observation: { specimen: "1" },
        field_code: field_slips(:field_slip_no_obs).code,
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.field_slips.one?)
  end

  def test_create_observation_with_collection_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Billy Bob", number: "17-034" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.one?)
  end

  def test_create_observation_with_used_collection_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Rolf Singer", number: "1" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.one?)
    assert_flash_warning
  end

  def test_create_observation_has_specimen_and_collector_but_no_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Rolf Singer", number: "" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_empty(obs.collection_numbers)
  end

  def test_create_observation_with_collection_number_but_no_specimen
    generic_construct_observation(
      { collection_number: { name: "Rolf Singer", number: "3141" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert_not(obs.specimen)
    assert_empty(obs.collection_numbers)
  end

  def test_create_observation_with_collection_number_but_no_collector
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "", number: "27-18A.2" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.one?)
    col_num = obs.collection_numbers.first
    assert_equal(rolf.legal_name, col_num.name)
    assert_equal("27-18A.2", col_num.number)
  end

  def test_create_observation_with_herbarium_record
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).autocomplete_name,
          accession_number: "1234"
        },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.herbarium_records.one?)
  end

  def test_create_observation_with_herbarium_duplicate_label
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).autocomplete_name,
          accession_number: "1234"
        },
        naming: { name: "Cortinarius sp." } },
      0, 0, 0, 0
    )
    assert_input_value(:herbarium_record_herbarium_name,
                       "NY - The New York Botanical Garden")
    assert_input_value(:herbarium_record_accession_number, "1234")
  end

  def test_create_observation_with_herbarium_no_id
    name = "Coprinus comatus"
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).autocomplete_name,
          accession_number: ""
        },
        naming: { name: name } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert_true(obs.specimen)
    assert_equal(0, obs.herbarium_records.count)
  end

  def test_create_observation_with_herbarium_but_no_specimen
    generic_construct_observation(
      { herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).autocomplete_name,
          accession_number: "1234"
        },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert_not(obs.specimen)
    assert(obs.herbarium_records.none?)
  end

  def test_create_observation_with_new_nonpersonal_herbarium
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: { herbarium_name: "A Brand New Herbarium",
                            accession_number: "" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_empty(obs.herbarium_records)
  end

  def test_create_observation_with_new_personal_herbarium
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: { herbarium_name: katrina.personal_herbarium_name,
                            accession_number: "12345" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0, katrina
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_equal(1, obs.herbarium_records.count)
    assert_not_empty(obs.herbarium_records)
    herbarium_record = obs.herbarium_records.first
    herbarium = herbarium_record.herbarium
    assert(herbarium.curator?(katrina))
    assert(herbarium.name.include?("Katrina"))
  end

  def test_create_simple_observation_with_approved_unique_name
    where = "Simple, Massachusetts, USA"
    generic_construct_observation(
      { observation: { place_name: where, thumb_image_id: "0" },
        naming: { name: "Coprinus comatus" } },
      1, 1, 0, 0
    )
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where)
    assert_equal(names(:coprinus_comatus).id, nam.name_id)
    assert_equal("2.03659",
                 format("%<vote_cache>.5f", vote_cache: obs.reload.vote_cache))
    assert_not_nil(obs.rss_log)
    # This was getting set to zero instead of nil if no images were uploaded
    # when obs was created.
    assert_nil(obs.thumb_image_id)
  end

  def test_create_simple_observation_of_unknown_taxon
    where = "Unknown, Massachusetts, USA"
    generic_construct_observation(
      { observation: { place_name: where }, naming: { name: "Unknown" } },
      1, 0, 0, 0
    )
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_new_name
    generic_construct_observation(
      { naming: { name: "New name" } }, 0, 0, 0, 0
    )
  end

  def test_create_observation_with_approved_new_name
    # Test an observation creation with an approved new name
    generic_construct_observation(
      { naming: { name: "Argus arg-arg" }, approved_name: "Argus arg-arg" },
      1, 1, 2, 0
    )
  end

  def test_create_observation_with_approved_name_and_extra_space
    generic_construct_observation(
      { naming: { name: "Another new-name  " },
        approved_name: "Another new-name  " },
      1, 1, 2, 0
    )
  end

  def test_create_observation_with_approved_section
    # (This is now supported nominally)
    # (Use Macrocybe because it already exists and has an author.
    # That way we know it is actually creating a name for this section.)
    generic_construct_observation(
      { naming: { name: "Macrocybe section Fakesection" },
        approved_name: "Macrocybe section Fakesection" },
      1, 1, 1, 0
    )
  end

  def test_create_observation_with_approved_junk_name
    generic_construct_observation(
      { naming: { name: "This is a bunch of junk" },
        approved_name: "This is a bunch of junk" },
      0, 0, 0, 0
    )
  end

  def test_create_observation_with_multiple_name_matches
    generic_construct_observation(
      { naming: { name: "Amanita baccata" } },
      0, 0, 0, 0
    )
  end

  def test_create_observation_choosing_one_of_multiple_name_matches
    generic_construct_observation(
      { naming: { name: "Amanita baccata" },
        chosen_name: { name_id: names(:amanita_baccata_arora).id } },
      1, 1, 0, 0
    )
  end

  def test_create_observation_choosing_deprecated_one_of_multiple_name_matches
    generic_construct_observation(
      { naming: { name: names(:pluteus_petasatus_deprecated).text_name } },
      1, 1, 0, 0
    )
    nam = assigns(:naming)
    assert_equal(names(:pluteus_petasatus_approved).id, nam.name_id)
  end

  def test_create_observation_with_deprecated_name
    generic_construct_observation(
      { naming: { name: "Lactarius subalpinus" } },
      0, 0, 0, 0
    )
  end

  def test_create_observation_with_chosen_approved_synonym_of_deprecated_name
    generic_construct_observation(
      { naming: { name: "Lactarius subalpinus" },
        approved_name: "Lactarius subalpinus",
        chosen_name: { name_id: names(:lactarius_alpinus).id } },
      1, 1, 0, 0
    )
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_alpinus))
  end

  def test_create_observation_with_approved_deprecated_name
    generic_construct_observation(
      { naming: { name: "Lactarius subalpinus" },
        approved_name: "Lactarius subalpinus",
        chosen_name: {} },
      1, 1, 0, 0
    )
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_subalpinus))
  end

  def test_create_observation_with_approved_new_species
    # Test an observation creation with an approved new name
    Name.find_by(text_name: "Agaricus").destroy
    generic_construct_observation(
      { naming: { name: "Agaricus novus" },
        approved_name: "Agaricus novus" },
      1, 1, 2, 0
    )
    name = Name.find_by(text_name: "Agaricus novus")
    assert(name)
    assert_equal("Agaricus novus", name.text_name)
  end

  def test_create_observation_that_generates_email
    name = names(:agaricus_campestris)
    name_trackers = NameTracker.where(name: name)
    assert_equal(2, name_trackers.length,
                 "Should be 2 name name_trackers for name ##{name.id}")
    assert(name_trackers.map(&:user).include?(mary))
    mary.update(no_emails: true)

    where = "Simple, Massachusetts, USA"
    # One tracker has no_emails, so only 1 email should be enqueued
    assert_enqueued_jobs(1) do
      generic_construct_observation(
        { observation: { place_name: where },
          naming: { name: name.text_name } },
        1, 1, 0, 0
      )
    end
    obs = assigns(:observation)
    nam = assigns(:naming)

    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name.id, nam.name_id) # Make sure it's the right name
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_unknown_decimal_geolocation_and_unknown_name
    # cannot use 0,0 because that's inside loc_edited_by_katrina
    lat = 3.0
    lng = 0.0
    earth = Location.unknown
    locs = Location.contains_point(lat: lat, lng: lng)
    assert_equal(1, locs.length,
                 "Test needs lat/lng outside all locations except Earth")
    assert_equal(earth, locs.first)

    generic_construct_observation(
      { observation: { place_name: "", lat: lat, lng: lng },
        naming: { name: "Unknown" } },
      1, 0, 0, 0
    )
    obs = assigns(:observation)

    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(lng.to_s, obs.lng.to_s)
    assert_objs_equal(earth, obs.location)
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_known_decimal_geolocation_and_unknown_name
    burbank = locations(:burbank)
    lat = burbank.center_lat
    lng = burbank.center_lng

    generic_construct_observation(
      { observation: { place_name: "", lat: lat, lng: lng },
        naming: { name: "Unknown" } },
      1, 0, 0, 0
    )

    obs = assigns(:observation)
    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(lng.to_s, obs.lng.to_s)
    assert_objs_equal(
      locations(:burbank), obs.location,
      "It should use smallest Location containing lat/lng " \
      "even if user leaves Where blank or uses the unknown Location"
    )
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_dms_geolocation_and_unknown_name
    lat2 = "34°9’43.92”N"
    lng2 = "118°21′7.56″W"
    generic_construct_observation(
      { observation: { place_name: "", lat: lat2, lng: lng2 },
        naming: { name: "Unknown" } },
      1, 0, 0, 0
    )
    obs = assigns(:observation)

    assert_equal("34.1622", obs.lat.to_s)
    assert_equal("-118.3521", obs.lng.to_s)
    assert_objs_equal(
      locations(:burbank), obs.location,
      "It should use smallest Location containing lat/lng " \
      "even if user leaves Where blank or uses the unknown Location"
    )
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_empty_geolocation_and_location
    # Make sure it doesn't accept no location AND no lat/long.
    generic_construct_observation(
      { observation: { place_name: "", lat: "", lng: "" },
        naming: { name: "Unknown" } },
      0, 0, 0, 0
    )
  end

  def test_create_observations_with_unknown_location_and_empty_geolocation
    # But create observation if explicitly tell it "unknown" location.
    generic_construct_observation(
      { observation: { place_name: "Earth", lat: "", lng: "" },
        naming: { name: "Unknown" } },
      1, 0, 0, 0
    )
  end

  def test_create_observation_with_various_altitude_formats
    [
      ["500",     500],
      ["500m",    500],
      ["500 ft.", 152],
      [" 500' ", 152]
    ].each do |input, output|
      where = "Unknown, Massachusetts, USA"

      generic_construct_observation(
        { observation: { place_name: where, alt: input },
          naming: { name: "Unknown" } },
        1, 0, 0, 0
      )
      obs = assigns(:observation)

      assert_equal(output, obs.alt)
      assert_equal(where, obs.where) # Make sure it's the right observation
      assert_not_nil(obs.rss_log)
    end
  end

  def test_create_observation_creating_class
    generic_construct_observation(
      { observation: { place_name: "Earth", lat: "", lng: "" },
        naming: { name: "Lecanoromycetes L." },
        approved_name: "Lecanoromycetes L." },
      1, 1, 1, 0
    )
    name = Name.last
    assert_equal("Lecanoromycetes", name.text_name)
    assert_equal("L.", name.author)
    assert_equal("Class", name.rank)
  end

  def test_create_observation_creating_family
    params = {
      observation: { place_name: "Earth", lat: "", lng: "" },
      naming: { name: "Acarosporaceae" },
      approved_name: "Acarosporaceae"
    }
    o_num = 1
    g_num = 1
    n_num = 1
    user = rolf
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    score   = user.reload.contribution
    params  = modified_generic_params(params, user)

    post_requires_login(:create, params)
    name = Name.last

    # assert_redirected_to(action: :show)
    assert_response(:redirect)
    assert_match(%r{/test.host/obs/\d+\Z}, @response.redirect_url)
    assert_equal(o_count + o_num, Observation.count, "Wrong Observation count")
    assert_equal(g_count + g_num, Naming.count, "Wrong Naming count")
    assert_equal(n_count + n_num, Name.count, "Wrong Name count")
    assert_equal(score + o_num + g_num * 2 + n_num * 10,
                 user.reload.contribution,
                 "Wrong User score")
    assert_not_equal(
      0,
      @controller.instance_variable_get(:@observation).thumb_image_id,
      "Wrong image id"
    )
    assert_equal("Acarosporaceae", name.text_name)
    assert_equal("Family", name.rank)
  end

  def test_create_observation_creating_group
    generic_construct_observation(
      { observation: { place_name: "Earth", lat: "", lng: "" },
        naming: { name: "Morchella elata group" },
        approved_name: "Morchella elata group" },
      1, 1, 2, 0
    )
    name = Name.last
    assert_equal("Morchella elata group", name.text_name)
    assert_equal("", name.author)
    assert_equal("Group", name.rank)
  end

  def test_prevent_creation_of_species_under_deprecated_genus
    login(katrina.login)
    cladonia = Name.find_or_create_name_and_parents(katrina, "Cladonia").last
    cladonia.save!
    cladonia_picta = Name.find_or_create_name_and_parents(katrina,
                                                          "Cladonia picta").last
    cladonia_picta.save!
    cladina = Name.find_or_create_name_and_parents(katrina, "Cladina").last
    cladina.change_deprecated(true)
    cladina.save!
    cladina.merge_synonyms(cladonia)

    generic_construct_observation(
      { observation: { place_name: "Earth" },
        naming: { name: "Cladina pictum" } },
      0, 0, 0, 0, roy
    )
    assert_names_equal(cladina, assigns(:parent_deprecated))
    assert_obj_arrays_equal([cladonia_picta], assigns(:valid_names))

    generic_construct_observation(
      { observation: { place_name: "Earth" },
        naming: { name: "Cladina pictum" },
        approved_name: "Cladina pictum" },
      1, 1, 1, 0, roy
    )

    name = Name.last
    assert_equal("Cladina pictum", name.text_name)
    assert_true(name.deprecated)
  end

  # The ones that should pass here now need to match fixtures, in order to
  # generate a location_id, or they will be rejected.
  def test_construct_observation_dubious_place_names
    # Location box necessary for new locations (these are all non-fixtures).
    params = {
      naming: { name: "Unknown" },
      location: { north: 35, south: 34, east: -117, west: -118 }
    }
    # Test a reversed name with a scientific user
    where = "USA, Massachusetts, Reversed"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1, roy
    )

    # Test missing space.
    where = "Reversible, Massachusetts,USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0
    )
    # (This is accepted now for some reason.)
    where = "USA,Massachusetts, Reversible"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1, roy
    )

    # Test a bogus country name
    where = "Bogus, Massachusetts, UAS"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0
    )
    where = "UAS, Massachusetts, Bogus"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0, roy
    )

    # Test a bad state name
    where = "Bad State Name, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0
    )
    where = "USA, Bad State Name"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0, roy
    )

    # Test mix of city and county
    where = "Burbank, Los Angeles Co., California, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1
    )
    # Location should now already exist (because of the above).
    where = "USA, California, Los Angeles Co., Burbank"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 0, roy
    )

    # Test mix of city and county
    where = "Falmouth, Barnstable Co., Massachusetts, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1
    )
    # Location should now already exist (because of the above).
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 0, roy
    )

    # Test some bad terms
    where = "Some County, Ohio, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0
    )
    where = "Old Rd, Ohio, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, 0, 0, 0
    )
    where = "Old Rd., Ohio, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1
    )

    # Test some acceptable additions
    where = "near Burbank, Southern California, USA"
    generic_construct_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, 0, 0, 1
    )
  end

  def test_name_resolution
    login("rolf")

    params = {
      observation: {
        when: Time.zone.now,
        place_name: "Somewhere, Massachusetts, USA",
        specimen: "0",
        thumb_image_id: "0"
      },
      naming: {
        vote: { value: "3" }
      }
    }
    expected_page = new_location_path

    # Can we create observation with existing genus?
    agaricus = names(:agaricus)
    params[:naming][:name] = "Agaricus"
    params[:approved_name] = nil
    post(:create, params: params)
    # assert_template(action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Agaricus sp"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Agaricus sp."
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    # Can we create observation with genus and add author?
    params[:naming][:name] = "Agaricus Author"
    params[:approved_name] = "Agaricus Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:naming][:name] = "Agaricus sp Author"
    params[:approved_name] = "Agaricus sp Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:naming][:name] = "Agaricus sp. Author"
    params[:approved_name] = "Agaricus sp. Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    params[:naming][:name] = "Agaricus Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Agaricus sp Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Agaricus sp. Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).reload.name_id)

    # Can we create observation with deprecated genus?
    psalliota = names(:psalliota)
    params[:naming][:name] = "Psalliota"
    params[:approved_name] = "Psalliota"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Psalliota sp"
    params[:approved_name] = "Psalliota sp"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)

    params[:naming][:name] = "Psalliota sp."
    params[:approved_name] = "Psalliota sp."
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)

    # Can we create observation with deprecated genus, adding author?
    params[:naming][:name] = "Psalliota Author"
    params[:approved_name] = "Psalliota Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:naming][:name] = "Psalliota sp Author"
    params[:approved_name] = "Psalliota sp Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:naming][:name] = "Psalliota sp. Author"
    params[:approved_name] = "Psalliota sp. Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).reload.name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)

    # Can we create new quoted genus?
    params[:naming][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create, params: params)
    # assert_template(controller: :observations, action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'One'", assigns(:observation).name.search_name)

    params[:naming][:name] = "'Two' sp"
    params[:approved_name] = "'Two' sp"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'Two'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'Two'", assigns(:observation).name.search_name)

    params[:naming][:name] = "Gen. 'Three' sp."
    params[:approved_name] = "Gen. 'Three' sp."
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'Three'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'Three'", assigns(:observation).name.search_name)

    params[:naming][:name] = "'One'"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)

    params[:naming][:name] = "'One' sp"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)

    params[:naming][:name] = "'One' sp."
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)

    # Can we create species under the quoted genus?
    params[:naming][:name] = "'One' foo"
    params[:approved_name] = "'One' foo"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One' foo",
                 assigns(:observation).reload.name.text_name)

    params[:naming][:name] = "'One' 'bar'"
    params[:approved_name] = "'One' 'bar'"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One' sp. 'bar'",
                 assigns(:observation).reload.name.text_name)

    params[:naming][:name] = "'One' Author"
    params[:approved_name] = "'One' Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'One' Author", assigns(:observation).name.search_name)

    params[:naming][:name] = "'One' sp Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'One' Author", assigns(:observation).name.search_name)

    params[:naming][:name] = "'One' sp. Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal("Gen. 'One'", assigns(:observation).reload.name.text_name)
    assert_equal("Gen. 'One' Author", assigns(:observation).name.search_name)
  end

  def test_create_observation_strip_images
    login("rolf")

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    old_img1 = images(:turned_over_image)
    old_img2 = images(:in_situ_image)
    assert_false(old_img1.gps_stripped)
    assert_false(old_img2.gps_stripped)
    assert_false(old_img1.transferred)
    assert_false(old_img2.transferred)

    orig_file = old_img1.full_filepath("orig")
    path = orig_file.sub(%r{/[^/]*$}, "")
    FileUtils.mkdir_p(path) unless File.directory?(path)
    FileUtils.cp(fixture, orig_file)

    post(
      :create,
      params: {
        observation: {
          when: Time.zone.now,
          place_name: "Burbank, California, USA",
          lat: "45.4545",
          lng: "-90.1234",
          alt: "456",
          specimen: "0",
          thumb_image_id: "0",
          gps_hidden: "1",
          image: {
            "0" => {
              image: fixture,
              copyright_holder: "me",
              when: Time.zone.now
            }
          },
          good_image_ids: "#{old_img1.id} #{old_img2.id}"
        }
      }
    )

    obs = Observation.last
    assert_equal(3, obs.images.length)
    new_img = (obs.images - [old_img1, old_img2]).first
    assert_true(new_img.gps_stripped)
    # We have script/process_image disabled for tests, so it doesn't actually
    # strip the uploaded image.
    # assert_not_equal(File.size(fixture),
    #                  File.size(new_img.full_filepath("orig")))

    # Make sure it stripped the image which had already been created.
    assert_true(old_img1.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(old_img1.full_filepath("orig")))

    # Second pre-existing image has missing file, so stripping should fail.
    assert_false(old_img2.reload.gps_stripped)
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons
    login("rolf")

    # If javascript isn't enabled, then checkbox isn't required.
    post(:create,
         params: {
           observation: { place_name: "Where, Japan", when: Time.zone.now },
           naming: {
             name: names(:coprinus_comatus).text_name,
             vote: { value: 3 },
             reasons: {
               "1" => { check: "0", notes: "" },
               "2" => { check: "0", notes: "foo" },
               "3" => { check: "1", notes: ""    },
               "4" => { check: "1", notes: "bar" }
             }
           }
         })
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.reasons_array.select(&:used?).map(&:num).sort
    assert_equal([2, 3, 4], reasons)

    # If javascript IS enabled, then checkbox IS required.
    post(:create,
         params: {
           observation: { place_name: "Where, Japan", when: Time.zone.now },
           naming: {
             name: names(:coprinus_comatus).text_name,
             vote: { value: 3 },
             reasons: {
               "1" => { check: "0", notes: "" },
               "2" => { check: "0", notes: "foo" },
               "3" => { check: "1", notes: ""    },
               "4" => { check: "1", notes: "bar" }
             }
           },
           was_js_on: "yes"
         })
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.reasons_array.select(&:used?).map(&:num).sort
    assert_equal([3, 4], reasons)
  end

  def test_create_with_image_upload
    login("rolf")

    time0 = Time.utc(2000)
    time1 = Time.utc(2001)
    time2 = Time.utc(2002)
    time3 = Time.utc(2003)
    week_ago = 1.week.ago

    setup_image_dirs
    file = Rails.root.join("test/images/Coprinus_comatus.jpg")
    file1 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file2 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file3 = Rack::Test::UploadedFile.new(file, "image/jpeg")

    new_image1 = Image.create(
      copyright_holder: "holder_1",
      when: time1,
      notes: "notes_1",
      user_id: users(:rolf).id,
      image: file1,
      content_type: "image/jpeg",
      created_at: week_ago
    )

    new_image2 = Image.create(
      copyright_holder: "holder_2",
      when: time2,
      notes: "notes_2",
      user_id: users(:rolf).id,
      image: file2,
      content_type: "image/jpeg",
      created_at: week_ago
    )

    # assert(new_image1.updated_at < 1.day.ago)
    # assert(new_image2.updated_at < 1.day.ago)
    File.stub(:rename, false) do
      post(
        :create,
        params: {
          observation: {
            place_name: "Zzyzx, Japan",
            when: time0,
            thumb_image_id: 0, # (make new image the thumbnail)
            notes: { Observation.other_notes_key => "blah" },
            image: {
              "0" => {
                image: file3,
                copyright_holder: "holder_3",
                when: time3,
                notes: "notes_3"
              }
            },
            good_image: {
              new_image1.id.to_s => {},
              new_image2.id.to_s => {
                notes: "notes_2_new"
              }
            },
            # (attach these two images once observation created)
            good_image_ids: "#{new_image1.id} #{new_image2.id}"
          }
        }
      )
    end
    assert_response(:redirect) # redirected = successfully created

    obs = Observation.find_by(where: "Zzyzx, Japan")
    assert_equal(rolf.id, obs.user_id)
    assert_equal(time0, obs.when)
    assert_equal("Zzyzx, Japan", obs.place_name)

    new_image1.reload
    new_image2.reload
    imgs = obs.images.sort_by(&:id)
    img_ids = imgs.map(&:id)
    assert_equal([new_image1.id, new_image2.id, new_image2.id + 1], img_ids)
    assert_equal(new_image2.id + 1, obs.thumb_image_id)
    assert_equal("holder_1", imgs[0].copyright_holder)
    assert_equal("holder_2", imgs[1].copyright_holder)
    assert_equal("holder_3", imgs[2].copyright_holder)
    assert_equal(time1, imgs[0].when)
    assert_equal(time2, imgs[1].when)
    assert_equal(time3, imgs[2].when)
    assert_equal("notes_1",     imgs[0].notes)
    assert_equal("notes_2_new", imgs[1].notes)
    assert_equal("notes_3",     imgs[2].notes)
    # assert(imgs[0].updated_at < 1.day.ago) # notes not changed
    # assert(imgs[1].updated_at > 1.day.ago) # notes changed
  end

  def test_image_upload_when_create_fails
    login("rolf")

    setup_image_dirs
    file = Rails.root.join("test/images/Coprinus_comatus.jpg")
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")
    File.stub(:rename, false) do
      post(
        :create,
        params: {
          observation: {
            place_name: "", # will cause failure
            when: Time.zone.now,
            image: { "0": { image: file,
                            copyright_holder: "zuul",
                            when: Time.zone.now } }
          }
        }
      )
      assert_response(:success) # success = failure, paradoxically
    end
    # Make sure image was created, but that it is unattached, and that it has
    # been kept in the @good_images array for attachment later.
    img = Image.find_by(copyright_holder: "zuul")
    assert(img)
    assert_equal([], img.observations)
    assert_equal([img.id],
                 @controller.instance_variable_get(:@good_images).map(&:id))
  end

  def test_image_upload_when_process_image_fails
    setup_image_dirs
    file = Rails.root.join("test/images/Coprinus_comatus.jpg")
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")
    image = Image.create(user: users(:rolf),
                         copyright_holder: "zuul",
                         when: Time.current,
                         notes: "stubbed in test")
    params = {
      observation: {
        place_name: "USA",
        when: Time.current,
        image: {
          "0" => {
            image: file,
            copyright_holder: "zuul",
            when: Time.current
          }
        }
      }
    }
    login("rolf")

    # Simulate process_image failure.
    Image.stub(:new, image) do
      image.stub(:process_image, false) do
        post(:create, params: params)
      end
    end

    img = Image.find_by(copyright_holder: "zuul")

    assert(img, "Failed to create image")
    assert_equal([], img.observations, "Image should be unattached")
    assert_includes(@controller.instance_variable_get(:@bad_images), img,
                    "Failed to include image in @bad_images")
    assert_empty(@controller.instance_variable_get(:@good_images),
                 "Incorrectly included image in @good_images")
  end

  # --------------------------------------------------------------------
  #  Test notes with template
  # --------------------------------------------------------------------

  # Prove that create_observation renders note fields with template keys first,
  # in the order listed in the template
  def test_new_observation_with_notes_template
    user = users(:notes_templater)
    login(user.login)
    get(:new)

    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "", Other: "" }
    )
  end

  def test_notes_to_name
    login("katrina")
    name = names(:coprinus_comatus)
    get(:new, params: { notes: { Field_Slip_ID: name.text_name } })

    assert_match(name.text_name, @response.body)
  end

  def test_collector_to_observation
    login("katrina")
    get(:new, params: { notes: { Collector: mary.textile_name } })

    assert_match(mary.textile_name, @response.body)
  end

  # Prove that notes are saved with template keys first, in the order listed in
  # the template, then Other, but without blank fields
  def test_create_observation_with_notes_template
    user = users(:notes_templater)
    params = { observation: sample_obs_fields }
    # Use defined Location to avoid issues with reloading Observation
    params[:observation][:place_name] = locations(:albion).name
    params[:observation][:notes] = {
      Nearby_trees: "?",
      Observation.other_notes_key => "Some notes",
      odor: "",
      Cap: "red"
    }
    expected_notes = {
      Cap: "red",
      Nearby_trees: "?",
      Observation.other_notes_key => "Some notes"
    }
    o_size = Observation.count

    login(user.login)
    post(:create, params: params)

    assert_equal(o_size + 1, Observation.count)
    obs = Observation.last.reload
    assert_redirected_to(action: :show, id: obs.id)
    assert_equal(expected_notes, obs.notes)
  end
end
