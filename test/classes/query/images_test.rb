# frozen_string_literal: true

require("test_helper")

# tests of Query::Images class to be included in QueryTest
module Query::ImagesTest
  def test_image_all
    expects = Image.index_order
    assert_query(expects, :Image)
  end

  def test_image_size
    expects = Image.index_order.with_sizes(:thumbnail)
    assert_query(expects, :Image, size: :thumbnail)
  end

  def test_image_content_types
    expects = Image.index_order.with_content_types(%w[jpg gif png])
    assert_query(expects, :Image, content_types: %w[jpg gif png])
    expects = Image.index_order.with_content_types(%w[raw])
    assert_query(expects, :Image, content_types: %w[raw])
  end

  def test_image_with_notes
    expects = Image.index_order.with_notes
    assert_query(expects, :Image, with_notes: true)
    expects = Image.index_order.without_notes
    assert_query(expects, :Image, with_notes: false)
  end

  def test_image_notes_has
    expects = Image.index_order.notes_contain('"looked like"')
    assert_query(expects, :Image, notes_has: '"looked like"')
    expects = Image.index_order.notes_contain("illustration -convex")
    assert_query(expects, :Image, notes_has: "illustration -convex")
  end

  def test_image_copyright_holder_has
    expects = Image.index_order.copyright_holder_contains('"Insil Choi"')
    assert_query(expects, :Image, copyright_holder_has: '"Insil Choi"')
  end

  def test_image_license
    expects = Image.index_order.with_license(License.preferred)
    assert_query(expects, :Image, license: License.preferred)
  end

  def test_image_with_votes
    expects = Image.index_order.with_votes
    assert_query(expects, :Image, with_votes: true)
    expects = Image.index_order.without_votes
    assert_query(expects, :Image, with_votes: false)
  end

  def test_image_quality
    expects = Image.index_order.with_quality(50)
    assert_query(expects, :Image, quality: 50)
    expects = Image.index_order.with_quality(30, 50)
    assert_query(expects, :Image, quality: [30, 50])
  end

  def test_image_confidence
    expects = Image.index_order.with_confidence(50)
    assert_query(expects, :Image, confidence: 50)
    expects = Image.index_order.with_confidence(30, 50)
    assert_query(expects, :Image, confidence: [30, 50])
  end

  def test_image_ok_for_export

  end

  def test_image_for_observations
    obs = observations(:two_img_obs)
    expects = Image.index_order.joins(:observations).
              where(observations: { id: obs.id }).distinct
    assert_query(expects, :Image, observations: obs)
  end

  def test_image_for_projects
    project = projects(:bolete_project)
    expects = Image.index_order.joins(:projects).
              where(projects: { id: project.id }).distinct
    assert_query(expects, :Image, projects: [project.title])
  end

  def test_image_by_user
    expects = Image.index_order.where(user_id: rolf.id).distinct
    assert_query(expects, :Image, by_user: rolf)
    expects = Image.index_order.where(user_id: mary.id).distinct
    assert_query(expects, :Image, by_user: mary)
    expects = Image.index_order.where(user_id: dick.id).distinct
    assert_query(expects, :Image, by_user: dick)
  end

  def test_image_in_set
    ids = [images(:turned_over_image).id,
           images(:agaricus_campestris_image).id,
           images(:disconnected_coprinus_comatus_image).id]
    assert_query(ids, :Image, ids: ids)
  end

  def test_image_inside_observation
    obs = observations(:detailed_unknown_obs)
    assert_equal(2, obs.images.length)
    expects = obs.images.sort_by(&:id)
    assert_query(expects, :Image,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
    obs = observations(:minimal_unknown_obs)
    assert_equal(0, obs.images.length)
    assert_query(obs.images, :Image,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
  end

  def test_image_for_project
    project = projects(:bolete_project)
    expects = Image.index_order.joins(:project_images).
              where(project_images: { project: project }).reorder(id: :asc)
    assert_query(expects, :Image, project: project, by: :id)
    assert_query([], :Image, project: projects(:empty_project))
  end

  def test_image_advanced_search_name
    # expects = [] # [images(:agaricus_campestris_image).id]
    expects = Image.index_order.joins(observations: :name).
              where(Name[:search_name].matches("%Agaricus%")).distinct
    assert_query(expects, :Image, name: "Agaricus")
  end

  def test_image_advanced_search_user_where
    expects = Image.index_order.joins(:observations).
              where(Observation[:where].matches("%burbank%")).
              where(observations: { is_collection_location: true }).distinct
    assert_query(expects, :Image, user_where: "burbank")

    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, user_where: "glendale")
  end

  def test_image_advanced_search_user
    expects = Image.index_order.joins(observations: :user).
              where(observations: { user: mary }).
              order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_query(expects, :Image, user: "mary")
  end

  def test_image_advanced_search_content
    assert_query(Image.index_order.search_content_and_associations("little"),
                 :Image, content: "little")
    assert_query(Image.index_order.search_content_and_associations("fruiting"),
                 :Image, content: "fruiting")
  end

  def test_image_advanced_search_combos
    assert_query([],
                 :Image, name: "agaricus", user_where: "glendale")
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, name: "agaricus", user_where: "burbank")
    assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
                 :Image, content: "little", user_where: "burbank")
  end

  def test_image_pattern_search
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, pattern: "agaricus") # name
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image, pattern: "bob dob") # copyright holder
    assert_query(
      [images(:in_situ_image).id],
      :Image, pattern: "looked gorilla OR original" # notes
    )
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id],
                 :Image, pattern: "notes some") # notes
    assert_query(
      [images(:turned_over_image).id, images(:in_situ_image).id],
      :Image, pattern: "dobbs -notes" # (c), not notes
    )
    assert_query([images(:in_situ_image).id], :Image,
                 pattern: "DSCN8835") # original filename
  end

  def test_image_with_observations
    expects = Image.index_order.includes(:observations).
              where.not(observations: { thumb_image: nil }).distinct
    assert_query(expects, :Image, with_observations: true)
  end

  # Prove that :with_observations param of Image Query works with each
  # parameter P for which (a) there's no other test of P for
  # Image, OR (b) P behaves differently in :with_observations than in
  # all other params of Image Query's.

  ##### date/time parameters #####

  def test_image_with_observations_created_at
    created_at = observations(:detailed_unknown_obs).created_at
    expects = Image.index_order.joins(:observations).
              where(Observation[:created_at] >= created_at).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image,
                 with_observations: 1, created_at: created_at)
  end

  def test_image_with_observations_updated_at
    updated_at = observations(:detailed_unknown_obs).updated_at
    expects = Image.index_order.joins(:observations).
              where(Observation[:updated_at] >= updated_at).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image,
                 with_observations: 1, updated_at: updated_at)
  end

  def test_image_with_observations_date
    date = observations(:detailed_unknown_obs).when
    expects = Image.index_order.joins(:observations).
              where(Observation[:when] >= date).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, date: date)
  end

  ##### list/string parameters #####

  def test_image_with_observations_comments_has
    expects = Image.index_order.joins(observations: :comments).
              where(Comment[:summary].matches("%give%")).
              or(Image.index_order.joins(observations: :comments).
                 where(Comment[:comment].matches("%give%"))).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image,
                 with_observations: 1, comments_has: "give")
  end

  def test_image_with_observations_with_notes_fields
    obs = observations(:substrate_notes_obs) # obs has notes substrate: field
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    expects = Image.index_order.joins(:observations).
              where(Observation[:notes].matches("%:substrate:%")).uniq
    assert_not_empty(expects, "'expects` is broken; it should not be empty")
    assert_query(expects, :Image,
                 with_observations: 1, with_notes_fields: "substrate")
  end

  def test_image_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Image.index_order.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, herbaria: name)
  end

  def test_image_with_observations_projects
    project = projects(:bolete_project)
    expects = Image.index_order.joins(observations: :projects).
              where(projects: { title: project.title }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects,
                 :Image, with_observations: 1, projects: [project.title])
  end

  def test_image_with_observations_users
    expects = Image.index_order.joins(:observations).
              where(observations: { user: dick }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, users: dick)
  end

  ##### numeric parameters #####

  def test_image_with_observations_bounding_box
    obs = give_geolocated_observation_some_images

    lat = obs.lat
    lng = obs.lng
    expects = Image.index_order.joins(:observations).
              where(observations: { lat: lat }).
              where(observations: { lng: lng }).distinct
    assert_query(
      expects,
      :Image,
      with_observations: 1,
      north: lat.to_f, south: lat.to_f, west: lat.to_f, east: lat.to_f
    )
  end

  def give_geolocated_observation_some_images
    obs = observations(:unknown_with_lat_lng) # obs has lat/lon
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    obs
  end

  ##### boolean parameters #####

  def test_image_with_observations_with_comments
    expects = Image.index_order.joins(observations: :comments).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects,
                 :Image, with_observations: 1, with_comments: true)
  end

  def test_image_with_observations_with_public_lat_lng
    give_geolocated_observation_some_images

    expects = Image.index_order.joins(:observations).
              where.not(observations: { lat: false }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects,
                 :Image, with_observations: 1, with_public_lat_lng: true)
  end

  def test_image_with_observations_with_name
    expects = Image.index_order.joins(:observations).
              where(observations: { name_id: Name.unknown }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, with_name: false)
  end

  def test_image_with_observations_with_notes
    expects = Image.index_order.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, with_notes: true)
  end

  def test_image_with_observations_with_sequences
    expects = Image.index_order.joins(observations: :sequences).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Image, with_observations: 1, with_sequences: true)
  end

  def test_image_with_observations_is_collection_location
    expects = Image.index_order.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects,
                 :Image, with_observations: 1, is_collection_location: true)
  end

  def test_image_with_observations_at_location
    expects = Image.index_order.joins(observations: :location).
              where(observations: { location: locations(:burbank) }).
              where(observations: { is_collection_location: true }).distinct
    assert_query(expects,
                 :Image, with_observations: 1, location: locations(:burbank).id)
    assert_query([], :Image,
                 with_observations: 1, location: locations(:mitrula_marsh).id)
  end

  def test_image_with_observations_at_where
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, with_observations: 1, user_where: "glendale")
    assert_query([],
                 :Image, with_observations: 1, user_where: "snazzle")
  end

  def test_image_with_observations_by_user
    expects = image_with_observations_by_user(rolf)
    assert_query(expects.to_a, :Image, with_observations: 1, by_user: rolf)

    expects = image_with_observations_by_user(mary)
    assert_query(expects.to_a, :Image, with_observations: 1, by_user: mary)

    assert_query([], :Image,
                 with_observations: 1, by_user: users(:zero_user))
  end

  def image_with_observations_by_user(user)
    Image.index_order.joins(:observations).
      where(observations: { user: user }).distinct
  end

  def test_image_with_observations_for_project
    assert_query([],
                 :Image,
                 with_observations: 1, project: projects(:empty_project))
    assert_query(observations(:two_img_obs).images.index_order.distinct,
                 :Image,
                 with_observations: 1, project: projects(:two_img_obs_project))
  end

  def test_image_with_observations_in_set
    obs_ids = [observations(:detailed_unknown_obs).id,
               observations(:agaricus_campestris_obs).id]
    # There's an order_by find_in_set thing here we can't do in Arel.
    # But luckily we can just quote the method.
    oids = obs_ids.join(",")
    expects = Image.joins(:observations).where(observations: { id: obs_ids }).
              reorder(Arel.sql("FIND_IN_SET(observations.id,'#{oids}')").asc,
                      Image[:id].desc).distinct
    assert_query(expects, :Image, with_observations: 1, obs_ids: obs_ids)
    assert_query([], :Image,
                 with_observations: 1,
                 obs_ids: [observations(:minimal_unknown_obs).id])
  end

  def test_image_with_observations_in_species_list
    assert_query([images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image,
                 with_observations: 1,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Image,
                 with_observations: 1,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_image_with_observations_of_children
    assert_query([images(:agaricus_campestris_image).id],
                 :Image,
                 with_observations: 1,
                 names: [names(:agaricus).id], include_subtaxa: true)
  end

  def test_image_sorted_by_original_name
    assert_query([images(:turned_over_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:disconnected_coprinus_comatus_image).id,
                  images(:in_situ_image).id,
                  images(:commercial_inquiry_image).id,
                  images(:agaricus_campestris_image).id],
                 :Image,
                 ids: [images(:in_situ_image).id,
                       images(:turned_over_image).id,
                       images(:commercial_inquiry_image).id,
                       images(:disconnected_coprinus_comatus_image).id,
                       images(:connected_coprinus_comatus_image).id,
                       images(:agaricus_campestris_image).id],
                 by: :original_name)
  end

  def test_image_with_observations_of_name
    expects = Image.index_order.joins(:observation_images, :observations).
              where(observations: { name: names(:fungi) }).distinct
    assert_query(expects,
                 :Image, with_observations: 1, names: [names(:fungi).id])
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image,
                 with_observations: 1, names: [names(:coprinus_comatus).id])
    assert_query([images(:agaricus_campestris_image).id],
                 :Image,
                 with_observations: 1, names: [names(:agaricus_campestris).id])
    assert_query([], :Image,
                 with_observations: 1, names: [names(:conocybe_filaris).id])
  end
end
