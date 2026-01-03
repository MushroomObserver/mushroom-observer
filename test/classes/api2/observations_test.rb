# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::ObservationsTest < UnitTestCase
  include API2Extensions

  def test_basic_observation_get
    do_basic_get_test(Observation)
  end

  # ---------------------------------
  #  :section: Observation Requests
  # ---------------------------------

  def params_get(**)
    { method: :get, action: :observation }.merge(**)
  end

  def obs_sample
    @obs_sample ||= Observation.all.sample
  end

  def test_getting_observations_id
    assert_api_pass(params_get(id: obs_sample.id))
    assert_api_results([obs_sample])
  end

  def obs_samples
    @obs_samples ||= Observation.all.sample(12).sort
  end

  def test_getting_observations_ids
    id_range = "#{obs_samples[0].id}-#{obs_samples[2].id}," \
               "#{obs_samples[3].id}-#{obs_samples[5].id}," \
               "#{obs_samples[6..11].map(&:id).join(",")}"
    assert_api_fail(params_get(id: id_range))
    assert_api_pass(params_get(id: obs_samples.map(&:id).join(",")))
    assert_api_results(obs_samples)
  end

  def test_getting_observations_year
    obses = Observation.where(Observation[:created_at].year.eq(2010))
    assert_not_empty(obses)
    assert_api_pass(params_get(created_at: "2010"))
    assert_api_results(obses)
  end

  def test_getting_observations_updated
    obses = Observation.updated_on("2007-06-24")
    assert_not_empty(obses)
    assert_api_pass(params_get(updated_at: "20070624"))
    assert_api_results(obses)
  end

  def test_getting_observations_year_between
    obses = Observation.where(Observation[:when].year.between(2012..2014))
    assert_not_empty(obses)
    assert_api_pass(params_get(date: "2012-2014"))
    assert_api_results(obses)
  end

  def test_getting_observations_user
    obses = Observation.where(user: dick)
    assert_not_empty(obses)
    assert_api_pass(params_get(user: "dick"))
    assert_api_results(obses)
  end

  def test_getting_observations_names
    obses = Observation.where(name: names(:fungi))
    assert_not_empty(obses)
    assert_api_pass(params_get(name: "Fungi"))
    assert_api_results(obses)
  end

  def test_getting_observations_names_and_where
    Observation.create!(user: rolf, when: Time.zone.now,
                        where: locations(:burbank),
                        name: names(:lactarius_alpinus))
    Observation.create!(user: rolf, when: Time.zone.now,
                        where: locations(:burbank),
                        name: names(:lactarius_alpigenes))
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    assert(obses.length > 1)
    assert_api_pass(params_get(synonyms_of: "Lactarius alpinus"))
    assert_api_results(obses)
    assert_api_pass(params_get(name: "Lactarius alpinus",
                               include_synonyms: "yes"))
    assert_api_results(obses)
  end

  def test_getting_observations_text_name
    assert_blank(
      Observation.where(text_name: "Agaricus"),
      "Tests won't work if there's already an Observation for genus Agaricus"
    )
    ssp_obs = Observation.names_like("Agaricus")
    assert(ssp_obs.length > 1)
    agaricus = Name.where(text_name: "Agaricus").first # (an existing autonym)s
    agaricus_obs = Observation.create(name: agaricus, user: rolf)
    assert_api_pass(params_get(children_of: "Agaricus"))
    assert_api_results(ssp_obs)
    assert_api_pass(params_get(name: "Agaricus", include_subtaxa: "yes"))
    assert_api_results(ssp_obs.to_a << agaricus_obs)
  end

  def test_getting_observations_locations
    obses = Observation.within_locations(locations(:burbank))
    assert(obses.length > 1)
    assert_api_pass(params_get(location: 'Burbank\, California\, USA'))
    assert_api_results(obses)
  end

  def test_getting_observations_herbaria
    obses = HerbariumRecord.where(herbarium: herbaria(:nybg_herbarium)).
            map(&:observations).flatten.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(
      params_get(herbarium: "The New York Botanical Garden")
    )
    assert_api_results(obses)
  end

  def test_getting_observations_herbarium_records
    rec = herbarium_records(:interesting_unknown)
    obses = rec.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params_get(herbarium_record: rec.id))
    assert_api_results(obses)
  end

  def test_getting_observations_projects
    proj = projects(:one_genus_two_species_project)
    obses = proj.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params_get(project: proj.id))
    assert_api_results(obses)
  end

  def test_getting_observations_species_lists
    spl = species_lists(:one_genus_three_species_list)
    obses = spl.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params_get(species_list: spl.id))
    assert_api_results(obses)
  end

  def test_getting_observations_confidence
    obses = Observation.where(vote_cache: 3)
    assert(obses.length > 1)
    assert_api_pass(params_get(confidence: "3.0"))
    assert_api_results(obses)
  end

  def test_getting_observations_collection_location
    obses = Observation.is_collection_location(false)
    assert(obses.length > 1)
    assert_api_pass(params_get(is_collection_location: "no"))
    assert_api_results(obses)
  end

  def test_getting_observations_has_images
    with    = Observation.has_images
    without = Observation.has_images(false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_images: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_images: "no"))
    assert_api_results(without)
  end

  def test_getting_observations_has_name
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    names = Name.where((Name[:rank] <= genus).or(Name[:rank].eq(group)))
    with = Observation.where(name: names)
    without = Observation.where.not(name: names)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_name: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_name: "no"))
    assert_api_results(without)
  end

  def test_getting_observations_has_comments
    with = Observation.has_comments
    without = Observation.has_comments(false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_comments: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_comments: "no"))
    assert_api_results(without)
  end

  def test_getting_observations_has_specimen
    with    = Observation.has_specimen
    without = Observation.has_specimen(false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_specimen: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_specimen: "no"))
    assert_api_results(without)
  end

  def test_getting_observations_has_notes
    # no_notes = Observation.no_notes_persisted
    # with = Observation.where("notes != ?", no_notes)
    # without = Observation.where("notes = ?", no_notes)
    # Nimmo note: Observation.no_notes_persisted is just no_notes.to_yaml
    # Observation.no_notes, not the above, works for comparison in Arel here.
    with = Observation.has_notes
    without = Observation.has_notes(false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_notes: "no"))
    assert_api_results(without)
  end

  def test_getting_observations_notes_has
    obses = Observation.notes_has(":substrate:").
            reject { |o| o.notes[:substrate].blank? }
    assert(obses.length > 1)
    assert_api_pass(params_get(has_notes_field: "substrate"))
    assert_api_results(obses)

    obses = Observation.notes_has("orphan")
    assert(obses.length > 1)
    assert_api_pass(params_get(notes_has: "orphan"))
    assert_api_results(obses)
  end

  def test_getting_observations_comments_has
    obses = Comment.where(
      Comment[:summary].concat(Comment[:comment]).matches("%let's%")
    ).map(&:target).uniq.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params_get(comments_has: "let's"))
    assert_api_results(obses)
  end

  def test_getting_observations_in_box
    obses = Observation.in_box(north: 35, south: 34, east: -118, west: -119)
    assert_not_empty(obses)
    assert_api_fail(params_get(south: 34, east: -118, west: -119))
    assert_api_fail(params_get(north: 35, east: -118, west: -119))
    assert_api_fail(params_get(north: 35, south: 34, west: -119))
    assert_api_fail(params_get(north: 35, south: 34, east: -118))
    assert_api_pass(params_get(north: 35, south: 34, east: -118, west: -119))
    assert_api_results(obses)
  end

  def test_getting_observations_region
    obses = Observation.region("California, USA")
    assert_not_empty(obses)
    assert_api_pass(params_get(region: "California, USA"))
    assert_api_results(obses)
  end

  def test_post_minimal_observation
    @user = rolf
    @name = Name.unknown
    @loc = locations(:unknown_location)
    @img1 = nil
    @img2 = nil
    @spl = nil
    @proj = nil
    @date = Time.zone.today
    @notes = Observation.no_notes
    @vote = Vote.maximum_vote
    @specimen = false
    @is_col_loc = true
    @lat = nil
    @long = nil
    @alt = nil
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere"
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    assert_obj_arrays_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_equal("mo_api", Observation.last.source)
    assert_api_fail(params.except(:location))
  end

  def test_post_observation_with_geoloc_and_earth
    burbank = locations(:burbank)
    @user = rolf
    @name = Name.unknown
    @loc = burbank
    @img1 = nil
    @img2 = nil
    @spl = nil
    @proj = nil
    @date = Time.zone.today
    @notes = Observation.no_notes
    @vote = Vote.maximum_vote
    @specimen = false
    @is_col_loc = true
    @lat = burbank.center_lat
    @long = burbank.center_lng
    @alt = nil
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      latitude: @lat,
      longitude: @long,
      location: "Earth"
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    assert_obj_arrays_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_equal("mo_api", Observation.last.source)
    assert_api_fail(params.except(:location))
  end

  def test_post_maximal_observation
    @user = rolf
    @name = names(:coprinus_comatus)
    @loc = locations(:albion)
    @img1 = images(:in_situ_image)
    @img2 = images(:turned_over_image)
    @spl = species_lists(:first_species_list)
    @proj = projects(:eol_project)
    @date = date("20120626")
    @notes = {
      Cap: "scaly",
      Gills: "inky",
      Stipe: "smooth",
      Other: "These are notes.\nThey look like this."
    }
    @reasons = {
      1 => "because I say",
      2 => "",
      3 => nil,
      4 => "K+ paisley"
    }
    @vote = 2.0
    @specimen = true
    @is_col_loc = true
    @lat = 39.229
    @long = -123.77
    @alt = 50
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      date: "20120626",
      notes: { Cap: "scaly",
               Gills: "inky\n",
               Veil: "",
               Stipe: "  smooth  ",
               Other: "These are notes.\nThey look like this.\n" },
      location: "USA, California, Albion",
      latitude: "39.229°N",
      longitude: "123.770°W",
      altitude: "50m",
      has_specimen: "yes",
      name: "Coprinus comatus",
      reason_1: @reasons[1],
      reason_2: @reasons[2],
      reason_4: @reasons[4],
      vote: "2",
      projects: @proj.id,
      species_lists: @spl.id,
      thumbnail: @img2.id,
      images: "#{@img1.id},#{@img2.id}",
      source: "mo_iphone_app"
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    assert_obj_arrays_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_equal("mo_iphone_app", Observation.last.source)
    assert_last_naming_correct
    assert_last_vote_correct
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(api_key: "this should fail"))
    assert_api_fail(params.merge(date: "yesterday"))
    assert_api_pass(params.merge(location: "This is a bogus location")) # ???
    assert_api_pass(params.merge(location: "New Place, Oregon, USA")) # ???
    assert_api_fail(params.except(:latitude)) # need to supply both or neither
    assert_api_fail(params.merge(longitude: "bogus"))
    assert_api_fail(params.merge(altitude: "bogus"))
    assert_api_fail(params.merge(has_specimen: "bogus"))
    assert_api_fail(params.merge(name: "Unknown name"))
    assert_api_fail(params.merge(vote: "take that"))
    assert_api_fail(params.merge(extra: "argument"))
    assert_api_fail(params.merge(thumbnail: "1234567"))
    assert_api_fail(params.merge(images: "1234567"))
    assert_api_fail(params.merge(projects: "1234567"))
    # Rolf is not a member of this project
    assert_api_fail(params.merge(projects: projects(:bolete_project).id))
    assert_api_fail(params.merge(species_lists: "1234567"))
    assert_api_fail(
      # owned by Mary
      params.merge(species_lists: species_lists(:unknown_species_list).id)
    )
  end

  def test_post_observation_with_no_log
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere",
      name: "Agaricus campestris",
      log: "no"
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.rss_log_id)
  end

  def test_post_observation_with_used_field_slip
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere",
      name: "Agaricus campestris",
      code: field_slips(:field_slip_one).code
    }
    assert_api_fail(params)
  end

  def test_post_observation_with_free_field_slip
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: "Anywhere",
      name: "Agaricus campestris",
      code: field_slips(:field_slip_no_obs).code
    }
    assert_api_pass(params)
  end

  def test_post_observation_scientific_location
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key
    }
    assert_equal("postal", rolf.location_format)

    params[:location] = "New Place, California, USA"
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal("New Place, California, USA", obs.where)

    params[:location] = "Burbank, California, USA"
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_equal("Burbank, California, USA", obs.where)
    assert_objs_equal(locations(:burbank), obs.location)

    # API no longer pays attention to user's location format preference!  This
    # is supposed to make it more consistent for apps.  It would be a real
    # problem because apps don't have access to the user's prefs, so they have
    # no way of knowing how to pass in locations on the behalf of the user.
    User.update(rolf.id, location_format: "scientific")
    assert_equal("scientific", rolf.reload.location_format)

    # params[:location] = "USA, California, Somewhere Else"
    params[:location] = "Somewhere Else, California, USA"
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal("Somewhere Else, California, USA", obs.where)

    params[:location] = "Burbank, California, USA"
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_equal("Burbank, California, USA", obs.where)
    assert_objs_equal(locations(:burbank), obs.location)
  end

  def test_post_observation_has_specimen
    params = {
      method: :post,
      action: :observation,
      api_key: @api_key.key,
      location: locations(:burbank).name,
      name: names(:peltigera).text_name
    }

    assert_api_fail(params.merge(has_specimen: "no", herbarium: "1"))
    assert_api_fail(params.merge(has_specimen: "no", collection_number: "1"))
    assert_api_fail(params.merge(has_specimen: "no", accession_number: "1"))
    assert_api_fail(params.merge(has_specimen: "yes", herbarium: "bogus"))

    assert_api_pass(params.merge(has_specimen: "yes"))

    obs = Observation.last
    spec = HerbariumRecord.last
    assert_objs_equal(rolf.personal_herbarium, spec.herbarium)
    assert_equal("Peltigera: MO #{obs.id}", spec.herbarium_label)
    assert_obj_arrays_equal([obs], spec.observations)

    nybg = herbaria(:nybg_herbarium)
    assert_api_pass(params.merge(has_specimen: "yes", herbarium: nybg.code,
                                 collection_number: "12345"))

    obs = Observation.last
    spec = HerbariumRecord.last
    assert_objs_equal(nybg, spec.herbarium)
    assert_equal("Peltigera: Rolf Singer 12345", spec.herbarium_label)
    assert_obj_arrays_equal([obs], spec.observations)
  end

  def test_patching_observations
    rolfs_obs = observations(:coprinus_comatus_obs)
    marys_obs = observations(:detailed_unknown_obs)
    assert(rolfs_obs.can_edit?(rolf))
    assert_not(marys_obs.can_edit?(rolf))
    params = {
      method: :patch,
      action: :observation,
      api_key: @api_key.key,
      id: rolfs_obs.id,
      set_date: "2012-12-12",
      set_location: 'Burbank\, California\, USA',
      set_has_specimen: "no",
      set_is_collection_location: "no"
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: marys_obs.id))
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_location: ""))
    assert_api_pass(params)
    rolfs_obs.reload
    assert_equal(Date.parse("2012-12-12"), rolfs_obs.when)
    assert_objs_equal(locations(:burbank), rolfs_obs.location)
    assert_equal("Burbank, California, USA", rolfs_obs.where)
    assert_equal(false, rolfs_obs.specimen)
    assert_equal(false, rolfs_obs.is_collection_location)

    params = {
      method: :patch,
      action: :observation,
      api_key: @api_key.key,
      id: rolfs_obs.id,
      set_latitude: "12.34",
      set_longitude: "-56.78",
      set_altitude: "901"
    }
    assert_api_fail(params.except(:set_latitude))
    assert_api_fail(params.except(:set_longitude))
    assert_api_pass(params)
    rolfs_obs.reload
    assert_in_delta(12.34, rolfs_obs.lat, MO.box_epsilon)
    assert_in_delta(-56.78, rolfs_obs.lng, MO.box_epsilon)
    assert_in_delta(901, rolfs_obs.alt, MO.box_epsilon)

    params = {
      method: :patch,
      action: :observation,
      api_key: @api_key.key,
      id: rolfs_obs.id
    }
    assert_api_pass(params.merge(set_notes: { Other: "wow!",
                                              Cap: "red",
                                              Ring: "none",
                                              Gills: "" }))
    rolfs_obs.reload
    assert_equal({ Cap: "red", Ring: "none", Other: "wow!" }, rolfs_obs.notes)
    assert_api_pass(params.merge(set_notes: { Cap: "" }))
    rolfs_obs.reload
    assert_equal({ Ring: "none", Other: "wow!" }, rolfs_obs.notes)

    rolfs_img = (rolf.images - rolfs_obs.images).first
    marys_img = mary.images.first
    assert_api_fail(params.merge(set_thumbnail: ""))
    assert_api_fail(params.merge(set_thumbnail: marys_img.id))
    assert_api_pass(params.merge(set_thumbnail: rolfs_img.id))
    rolfs_obs.reload
    assert_objs_equal(rolfs_img, rolfs_obs.thumb_image)
    assert(rolfs_obs.images.include?(rolfs_img))
    imgs = rolf.images.map { |img| img.id.to_s }.join(",")
    assert_api_fail(params.merge(add_images: marys_img.id))
    assert_api_pass(params.merge(add_images: imgs))
    rolfs_obs.reload
    assert_objs_equal(rolfs_img, rolfs_obs.thumb_image)
    assert_obj_arrays_equal(rolf.images, rolfs_obs.images, :sort)
    assert_api_pass(params.merge(remove_images: rolfs_img.id))
    rolfs_obs.reload
    assert(rolfs_obs.thumb_image != rolfs_img)
    assert_objs_equal(rolfs_obs.images.first, rolfs_obs.thumb_image)
    imgs = rolf.images[2..6].map { |img| img.id.to_s }.join(",")
    imgs += ",#{marys_img.id}"
    assert_api_pass(params.merge(remove_images: imgs))
    rolfs_obs.reload
    assert_obj_arrays_equal(rolf.images - rolf.images[2..6] - [rolfs_img],
                            rolfs_obs.images, :sort)

    proj = projects(:bolete_project)
    proj.admin_group.users << rolf
    proj.user_group.users << rolf
    rolf.reload
    assert_not(proj.observations.include?(rolfs_obs))
    assert(proj.observations.include?(marys_obs))
    assert(rolfs_obs.can_edit?(rolf))
    assert(marys_obs.can_edit?(rolf))
    assert(rolfs_obs.user == rolf)
    assert(marys_obs.user == mary)
    assert_api_pass(params.merge(id: rolfs_obs.id, set_date: "2013-01-01"))
    assert_api_pass(params.merge(id: marys_obs.id, set_date: "2013-01-01"))
    assert_equal(Date.parse("2013-01-01"), rolfs_obs.reload.when)
    assert_equal(Date.parse("2013-01-01"), marys_obs.reload.when)
    assert_api_pass(params.merge(id: rolfs_obs.id, add_to_project: proj.id))
    assert_api_fail(params.merge(id: marys_obs.id, add_to_project: proj.id))
    assert(Project.find(proj.id).observations.include?(rolfs_obs))
    assert(Project.find(proj.id).observations.include?(marys_obs))
    assert_api_pass(params.merge(id: rolfs_obs.id,
                                 remove_from_project: proj.id))
    assert_api_fail(params.merge(id: marys_obs.id,
                                 remove_from_project: proj.id))
    assert_not(Project.find(proj.id).observations.include?(rolfs_obs))
    assert(Project.find(proj.id).observations.include?(marys_obs))

    spl1 = species_lists(:unknown_species_list)
    spl2 = species_lists(:query_first_list)
    assert(spl1.can_edit?(rolf))
    assert_not(spl2.can_edit?(rolf))
    assert_api_pass(params.merge(add_to_species_list: spl1.id))
    assert_api_fail(params.merge(add_to_species_list: spl2.id))
    assert(spl1.reload.observations.include?(rolfs_obs))
    assert_not(spl2.reload.observations.include?(rolfs_obs))
    assert_api_pass(params.merge(remove_from_species_list: spl1.id))
    assert_api_fail(params.merge(remove_from_species_list: spl2.id))
    assert_not(spl1.reload.observations.include?(rolfs_obs))
    assert_not(spl2.reload.observations.include?(rolfs_obs))
  end

  def test_deleting_observations
    rolfs_obs = rolf.observations.sample
    marys_obs = mary.observations.sample
    params = {
      method: :delete,
      action: :observation,
      api_key: @api_key.key
    }
    assert_api_fail(params.merge(id: marys_obs.id))
    assert_api_pass(params.merge(id: rolfs_obs.id))
    assert_not_nil(Observation.safe_find(marys_obs.id))
    assert_nil(Image.safe_find(rolfs_obs.id))
  end
end
