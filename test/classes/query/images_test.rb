# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Images class to be included in QueryTest
class Query::ImagesTest < UnitTestCase
  include QueryExtensions

  def test_image_all
    expects = Image.index_order
    assert_query(expects, :Image)
  end

  def test_image_size
    expects = Image.index_order.with_sizes(:thumbnail)
    assert_query(expects, :Image, size: :thumbnail)
    expects = Image.index_order.with_sizes(:thumbnail, :medium)
    assert_query(expects, :Image, size: [:thumbnail, :medium])
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
    expects = Image.index_order.quality(3)
    assert_query(expects, :Image, quality: 3)
    expects = Image.index_order.quality(3, 3.6)
    assert_query(expects, :Image, quality: [3, 3.6])
    expects = Image.index_order.quality([3, 3.6]) # array
    assert_query(expects, :Image, quality: [3, 3.6])
  end

  def test_image_confidence
    expects = Image.index_order.confidence(2.1)
    assert_query(expects, :Image, confidence: 2.1)
    expects = Image.index_order.confidence(1.2, 2.7)
    assert_query(expects, :Image, confidence: [1.2, 2.7])
    expects = Image.index_order.confidence([1.2, 2.7]) # array
    assert_query(expects, :Image, confidence: [1.2, 2.7])
  end

  def test_image_ok_for_export
    expects = Image.index_order.ok_for_export
    assert_query(expects, :Image, ok_for_export: true)
    expects = Image.index_order.not_ok_for_export
    assert_query(expects, :Image, ok_for_export: false)
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
              where(observations: { user: mary }).distinct.
              order(Image[:created_at].desc, Image[:id].desc)
    assert_query(expects, :Image, user: "mary")
  end

  def test_image_advanced_search_content
    assert_query(Image.index_order.
                 advanced_search("little"),
                 :Image, content: "little")
    assert_query(Image.index_order.
                 advanced_search("fruiting"),
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

  def test_image_pattern_search_name
    assert_query(Image.index_order.pattern_search("agaricus"),
                 :Image, pattern: "agaricus") # name
  end

  def test_image_pattern_search_copyright_holder
    assert_query(Image.index_order.pattern_search("bob dob"),
                 :Image, pattern: "bob dob") # copyright holder
  end

  def test_image_pattern_search_notes
    assert_query(
      Image.index_order.
      pattern_search("looked gorilla OR original"),
      :Image, pattern: "looked gorilla OR original" # notes
    )
    assert_query(Image.index_order.
                 pattern_search("notes some"),
                 :Image, pattern: "notes some") # notes
    assert_query(
      Image.index_order.pattern_search("dobbs -notes"),
      :Image, pattern: "dobbs -notes" # (c), not notes
    )
  end

  def test_image_pattern_search_original_filename
    assert_query(Image.index_order.pattern_search("DSCN8835"),
                 :Image, pattern: "DSCN8835") # original filename
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

  def assert_image_obs_query(expects, **params)
    assert_query(expects, :Image, observation_query: params)
  end

  def test_image_with_observations_created_at
    created_at = observations(:detailed_unknown_obs).created_at
    expects = Image.index_order.joins(:observations).
              where(Observation[:created_at] >= created_at).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, created_at:)
  end

  def test_image_with_observations_updated_at
    updated_at = observations(:detailed_unknown_obs).updated_at
    expects = Image.index_order.joins(:observations).
              where(Observation[:updated_at] >= updated_at).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, updated_at:)
  end

  def test_image_with_observations_date
    date = observations(:detailed_unknown_obs).when
    expects = Image.index_order.joins(:observations).
              where(Observation[:when] >= date).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, date:)
  end

  ##### list/string parameters #####

  def test_image_with_observations_comments_has
    expects = Image.index_order.joins(observations: :comments).
              where(Comment[:summary].matches("%give%")).
              or(Image.index_order.joins(observations: :comments).
                 where(Comment[:comment].matches("%give%"))).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, comments_has: "give")
  end

  def test_image_with_observations_with_notes_fields
    obs = observations(:substrate_notes_obs) # obs has notes substrate: field
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    expects = Image.index_order.joins(:observations).
              where(Observation[:notes].matches("%:substrate:%")).uniq
    assert_not_empty(expects, "'expects` is broken; it should not be empty")
    assert_image_obs_query(expects, with_notes_fields: "substrate")
  end

  def test_image_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Image.index_order.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, herbaria: name)
  end

  def test_image_with_observations_projects
    project = projects(:bolete_project)
    expects = Image.index_order.joins(observations: :projects).
              where(projects: { title: project.title }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, projects: [project.title])
  end

  def test_image_with_observations_users
    expects = Image.index_order.joins(:observations).
              where(observations: { user: dick }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, by_users: dick)
  end

  ##### numeric parameters #####

  def test_image_with_observations_bounding_box
    obs = give_geolocated_observation_some_images

    lat = obs.lat
    lng = obs.lng
    expects = Image.index_order.joins(:observations).
              where(observations: { lat: lat }).
              where(observations: { lng: lng }).distinct
    box = { north: lat.to_f, south: lat.to_f, west: lng.to_f, east: lng.to_f }
    assert_image_obs_query(expects, in_box: box)
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
    assert_image_obs_query(expects, with_comments: true)
  end

  def test_image_with_observations_with_public_lat_lng
    give_geolocated_observation_some_images

    expects = Image.index_order.joins(:observations).
              where.not(observations: { lat: false }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, with_public_lat_lng: true)
  end

  def test_image_with_observations_with_name
    expects = Image.index_order.joins(:observations).
              where(observations: { name_id: Name.unknown }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, with_name: false)
  end

  def test_image_with_observations_with_notes
    expects = Image.index_order.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, with_notes: true)
  end

  def test_image_with_observations_with_sequences
    expects = Image.index_order.joins(observations: :sequences).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, with_sequences: true)
  end

  def test_image_with_observations_is_collection_location
    expects = Image.index_order.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, is_collection_location: true)
  end

  def test_image_with_observations_at_location
    expects = Image.index_order.joins(observations: :location).
              where(observations: { location: locations(:burbank) }).
              where(observations: { is_collection_location: true }).distinct
    assert_image_obs_query(expects, location: locations(:burbank).id)
    assert_image_obs_query([], location: locations(:mitrula_marsh).id)
  end

  def test_image_with_observations_at_where
    expects = [images(:connected_coprinus_comatus_image).id]
    assert_image_obs_query(expects, user_where: "glendale")
    assert_image_obs_query([], user_where: "snazzle")
  end

  def test_image_with_observations_by_user
    expects = image_with_observations_by_user(rolf).to_a
    assert_image_obs_query(expects, by_user: rolf)

    expects = image_with_observations_by_user(mary).to_a
    assert_image_obs_query(expects, by_user: mary)

    assert_image_obs_query([], by_user: users(:zero_user))
  end

  def image_with_observations_by_user(user)
    Image.index_order.joins(:observations).
      where(observations: { user: user }).distinct
  end

  def test_image_with_observations_for_project
    assert_image_obs_query([], project: projects(:empty_project))
    expects = observations(:two_img_obs).images.index_order.distinct
    assert_image_obs_query(expects, project: projects(:two_img_obs_project))
  end

  def test_image_with_observations_in_set
    obs_ids = [observations(:detailed_unknown_obs).id,
               observations(:agaricus_campestris_obs).id]
    expects = Image.joins(:observations).where(observations: { id: obs_ids }).
              index_order.distinct
    assert_image_obs_query(expects, ids: obs_ids)
    assert_image_obs_query([], ids: [observations(:minimal_unknown_obs).id])
  end

  def test_image_with_observations_in_species_list
    expects = [images(:turned_over_image).id, images(:in_situ_image).id]
    spl_ids = species_lists(:unknown_species_list).id
    assert_image_obs_query(expects, species_lists: spl_ids)

    spl_ids = species_lists(:first_species_list).id
    assert_image_obs_query([], species_lists: spl_ids)
  end

  def test_image_with_observations_of_children
    expects = [images(:agaricus_campestris_image).id]
    params = { names: [names(:agaricus).id], include_subtaxa: true }
    assert_image_obs_query(expects, **params)
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
    assert_image_obs_query(expects, names: [names(:fungi).id])
    expects = [images(:connected_coprinus_comatus_image).id]
    assert_image_obs_query(expects, names: [names(:coprinus_comatus).id])
    expects = [images(:agaricus_campestris_image).id]
    assert_image_obs_query(expects, names: [names(:agaricus_campestris).id])
    assert_image_obs_query([], names: [names(:conocybe_filaris).id])
  end
end
