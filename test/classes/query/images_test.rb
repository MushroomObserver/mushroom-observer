# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Images class to be included in QueryTest
class Query::ImagesTest < UnitTestCase
  include QueryExtensions

  def test_image_all
    expects = Image.order_by_default
    assert_query(expects, :Image)
  end

  def test_image_sizes
    expects = Image.sizes(:thumbnail).order_by_default
    assert_query(expects, :Image, sizes: :thumbnail)
    expects = Image.sizes(:thumbnail, :medium).order_by_default
    assert_query(expects, :Image, sizes: [:thumbnail, :medium])
  end

  def test_image_content_types
    expects = Image.content_types(%w[jpg gif png]).order_by_default
    assert_query(expects, :Image, content_types: %w[jpg gif png])
    expects = Image.content_types(%w[raw]).order_by_default
    assert_query(expects, :Image, content_types: %w[raw])
  end

  def test_image_has_notes
    expects = Image.has_notes.order_by_default
    assert_query(expects, :Image, has_notes: true)
    expects = Image.has_notes(false).order_by_default
    assert_query(expects, :Image, has_notes: false)
  end

  def test_image_notes_has
    expects = Image.notes_has('"looked like"').order_by_default
    assert_query(expects, :Image, notes_has: '"looked like"')
    expects = Image.notes_has("illustration -convex").order_by_default
    assert_query(expects, :Image, notes_has: "illustration -convex")
  end

  def test_image_copyright_holder_has
    expects = Image.copyright_holder_has('"Insil Choi"').order_by_default
    assert_query(expects, :Image, copyright_holder_has: '"Insil Choi"')
  end

  def test_image_license
    expects = Image.license(License.preferred).order_by_default
    assert_query(expects, :Image, license: License.preferred)
  end

  def test_image_has_votes
    expects = Image.has_votes.order_by_default
    assert_query(expects, :Image, has_votes: true)
    expects = Image.has_votes(false).order_by_default
    assert_query(expects, :Image, has_votes: false)
  end

  def test_image_quality
    expects = Image.quality(3).order_by_default
    assert_query(expects, :Image, quality: 3)
    expects = Image.quality(3, 3.6).order_by_default
    assert_query(expects, :Image, quality: [3, 3.6])
    expects = Image.quality([3, 3.6]).order_by_default # array
    assert_query(expects, :Image, quality: [3, 3.6])
  end

  def test_image_confidence
    expects = Image.confidence(2.1).order_by_default
    assert_query(expects, :Image, confidence: 2.1)
    expects = Image.confidence(1.2, 2.7).order_by_default
    assert_query(expects, :Image, confidence: [1.2, 2.7])
    expects = Image.confidence([1.2, 2.7]).order_by_default # array
    assert_query(expects, :Image, confidence: [1.2, 2.7])
  end

  def test_image_ok_for_export
    expects = Image.ok_for_export.order_by_default
    assert_query(expects, :Image, ok_for_export: true)
    expects = Image.ok_for_export(false).order_by_default
    assert_query(expects, :Image, ok_for_export: false)
  end

  def test_image_observations
    obs = observations(:two_img_obs)
    scope = Image.observations(obs.id).order_by_default
    assert_query(scope, :Image, observations: obs)
  end

  def test_image_locations
    locations = Location.order_by_default.last(3)
    scope = Image.locations(locations).order_by_default
    assert_query(scope, :Image, locations: locations)
  end

  def test_image_projects
    project = projects(:bolete_project)
    scope = Image.projects(project.id).order_by_default
    assert_query(scope, :Image, projects: [project.title])
  end

  def test_image_species_lists
    spl = species_lists(:query_first_list)
    scope = Image.species_lists(spl.id).order_by_default
    assert_query(scope, :Image, species_lists: spl)
  end

  def test_image_by_users
    expects = Image.by_users(rolf.id).order_by_default
    assert_query(expects, :Image, by_users: rolf)
    expects = Image.by_users(mary.id).order_by_default
    assert_query(expects, :Image, by_users: mary)
    expects = Image.by_users(dick.id).order_by_default
    assert_query(expects, :Image, by_users: dick)
  end

  def test_image_id_in_set
    ids = [images(:turned_over_image).id,
           images(:agaricus_campestris_image).id,
           images(:disconnected_coprinus_comatus_image).id]
    scope = Image.id_in_set(ids).order(id: :desc)
    assert_query_scope(ids, scope, :Image, id_in_set: ids)
  end

  def test_image_inside_observation
    obs = observations(:detailed_unknown_obs)
    assert_equal(2, obs.images.length)
    expects = obs.images.sort_by(&:id).reverse
    assert_query(expects, :Image, observations: obs)
    obs = observations(:minimal_unknown_obs)
    assert_equal(0, obs.images.length)
    assert_query(obs.images, :Image, observations: obs)
  end

  def test_image_for_project
    project = projects(:bolete_project)
    expects = Image.joins(:project_images).distinct.
              where(project_images: { project: project }).reorder(id: :asc)
    assert_query(expects, :Image, projects: project, order_by: :id)
    assert_query([], :Image, projects: projects(:empty_project))
  end

  # Image advanced search is 86'd because too expensive.
  # def test_image_advanced_search_name
  #   # expects = [] # [images(:agaricus_campestris_image).id]
  #   expects = Image.order_by_default.joins(observations: :name).
  #             where(Name[:search_name].matches("%Agaricus%")).distinct
  #   assert_query(expects, :Image, search_name: "Agaricus")
  # end

  # def test_image_advanced_search_where
  #   expects = Image.order_by_default.joins(:observations).
  #             where(Observation[:where].matches("%burbank%")).
  #             where(observations: { is_collection_location: true }).distinct
  #   assert_query(expects, :Image, search_where: "burbank")

  #   assert_query([images(:connected_coprinus_comatus_image).id],
  #                :Image, search_where: "glendale")
  # end

  # def test_image_advanced_search_user
  #   expects = Image.order_by_default.joins(observations: :user).
  #             where(observations: { user: mary }).distinct.
  #             order(Image[:created_at].desc, Image[:id].desc)
  #   assert_query(expects, :Image, search_user: "mary")
  # end

  # def test_image_advanced_search_content
  #   assert_query(Image.order_by_default.
  #                advanced_search("little"),
  #                :Image, search_content: "little")
  #   assert_query(Image.order_by_default.
  #                advanced_search("fruiting"),
  #                :Image, search_content: "fruiting")
  # end

  # def test_image_advanced_search_combos
  #   assert_query([],
  #                :Image, search_name: "agaricus", search_where: "glendale")
  #   assert_query([images(:agaricus_campestris_image).id],
  #                :Image, search_name: "agaricus", search_where: "burbank")
  #   assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
  #                :Image, search_content: "little", search_where: "burbank")
  # end

  def test_image_pattern_search_name
    assert_query(Image.pattern("agaricus").order_by_default,
                 :Image, pattern: "agaricus") # name
  end

  def test_image_pattern_copyright_holder
    assert_query(Image.pattern("bob dob").order_by_default,
                 :Image, pattern: "bob dob") # copyright holder
  end

  def test_image_pattern_notes
    assert_query(
      Image.pattern("looked gorilla OR original").order_by_default,
      :Image, pattern: "looked gorilla OR original" # notes
    )
    assert_query(Image.pattern("notes some").order_by_default,
                 :Image, pattern: "notes some") # notes
    assert_query(
      Image.pattern("dobbs -notes").order_by_default,
      :Image, pattern: "dobbs -notes" # (c), not notes
    )
  end

  def test_image_pattern_original_filename
    assert_query(Image.pattern("DSCN8835").order_by_default,
                 :Image, pattern: "DSCN8835") # original filename
  end

  def test_image_has_observations
    expects = Image.includes(:observations).distinct.
              where.not(observations: { thumb_image: nil }).order_by_default
    scope = Image.has_observations.order_by_default
    assert_query_scope(expects, scope, :Image, has_observations: true)
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
    created_at = observations(:detailed_unknown_obs).created_at.as_json[0..9]
    expects = Image.joins(:observations).distinct.
              merge(Observation.created_at(created_at)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, created_at:)
  end

  def test_image_with_observations_updated_at
    updated_at = observations(:detailed_unknown_obs).updated_at.as_json[0..9]
    expects = Image.joins(:observations).distinct.
              merge(Observation.updated_at(updated_at)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, updated_at:)
  end

  def test_image_with_observations_date
    date = observations(:detailed_unknown_obs).when.as_json
    expects = Image.joins(:observations).distinct.
              merge(Observation.date(date)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, date:)
  end

  ##### list/string parameters #####

  def test_image_with_observations_comments_has
    expects = Image.joins(:observations).distinct.
              merge(Observation.comments_has("give")).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, comments_has: "give")
  end

  def test_image_with_observations_has_notes_fields
    obs = observations(:substrate_notes_obs) # obs has notes substrate: field
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    expects = Image.joins(:observations).distinct.
              merge(Observation.has_notes_fields("substrate")).order_by_default
    assert_not_empty(expects, "'expects` is broken; it should not be empty")
    assert_image_obs_query(expects, has_notes_fields: "substrate")
  end

  def test_image_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Image.joins(:observations).distinct.
              merge(Observation.herbaria(name)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, herbaria: name)
  end

  def test_image_with_observations_projects
    assert_image_obs_query([], projects: projects(:empty_project))

    project = projects(:bolete_project)
    expects = Image.joins(:observations).distinct.
              merge(Observation.projects(project.title)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, projects: [project.title])

    expects = observations(:two_img_obs).images.order_by_default.distinct
    project = projects(:two_img_obs_project)
    assert_image_obs_query(expects, projects: project)

    expects = Image.joins(:observations).distinct.
              merge(Observation.projects(project)).order_by_default
    assert_image_obs_query(expects, projects: project)
  end

  def test_image_with_observations_species_lists
    expects = [images(:turned_over_image).id, images(:in_situ_image).id]
    spl_ids = species_lists(:unknown_species_list).id
    assert_image_obs_query(expects, species_lists: spl_ids)
    expects = Image.joins(:observations).distinct.
              merge(Observation.species_lists(spl_ids)).order_by_default
    assert_image_obs_query(expects, species_lists: spl_ids)

    spl_ids = species_lists(:first_species_list).id
    assert_image_obs_query([], species_lists: spl_ids)
  end

  ##### numeric parameters #####

  def test_image_with_observations_bounding_box
    obs = give_geolocated_observation_some_images

    lat = obs.lat
    lng = obs.lng
    box = { north: lat.to_f, south: lat.to_f, west: lng.to_f, east: lng.to_f }
    expects = Image.joins(:observations).distinct.
              merge(Observation.in_box(**box)).order_by_default
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

  def test_image_with_observations_has_comments
    expects = Image.joins(:observations).distinct.
              merge(Observation.has_comments).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, has_comments: true)
  end

  def test_image_with_observations_has_public_lat_lng
    give_geolocated_observation_some_images

    expects = Image.joins(:observations).distinct.
              merge(Observation.has_public_lat_lng).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, has_public_lat_lng: true)
  end

  def test_image_with_observations_has_name
    expects = Image.joins(:observations).distinct.
              merge(Observation.has_name(false)).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, has_name: false)
  end

  def test_image_with_observations_has_notes
    expects = Image.joins(:observations).distinct.
              merge(Observation.has_notes).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, has_notes: true)
  end

  def test_image_with_observations_has_sequences
    expects = Image.joins(:observations).distinct.
              merge(Observation.has_sequences).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, has_sequences: true)
  end

  def test_image_with_observations_is_collection_location
    expects = Image.joins(:observations).distinct.
              merge(Observation.is_collection_location).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_image_obs_query(expects, is_collection_location: true)
  end

  def test_image_with_observations_locations
    expects = Image.joins(:observations).distinct.
              merge(Observation.locations(locations(:burbank))).order_by_default
    assert_image_obs_query(expects, locations: locations(:burbank).id)
    assert_image_obs_query([], locations: locations(:mitrula_marsh).id)
  end

  def test_image_with_observations_at_where
    expects = [images(:connected_coprinus_comatus_image).id]
    assert_image_obs_query(expects, search_where: "glendale")
    expects = Image.joins(:observations).distinct.
              merge(Observation.search_where("glendale")).order_by_default
    assert_image_obs_query(expects, search_where: "glendale")
    assert_image_obs_query([], search_where: "snazzle")
  end

  def test_image_with_observations_by_users
    users = [dick, rolf, mary]
    users.each do |user|
      expects = Image.joins(:observations).distinct.
                merge(Observation.by_users(user)).order_by_default

      assert_image_obs_query(expects, by_users: user)
    end

    assert_image_obs_query([], by_users: users(:zero_user))
  end

  def test_image_with_observations_in_set
    set = [observations(:detailed_unknown_obs).id,
           observations(:agaricus_campestris_obs).id]
    expects = Image.joins(:observations).distinct.
              merge(Observation.id_in_set(set).reorder("")).order_by_default
    assert_image_obs_query(expects, id_in_set: set)

    assert_image_obs_query(
      [], id_in_set: [observations(:minimal_unknown_obs).id]
    )
  end

  def sorted_by_name_set
    [
      images(:turned_over_image).id,
      images(:connected_coprinus_comatus_image).id,
      images(:disconnected_coprinus_comatus_image).id,
      images(:in_situ_image).id,
      images(:commercial_inquiry_image).id,
      images(:agaricus_campestris_image).id
    ].freeze
  end

  def test_image_sorted_by_original_name
    assert_query(
      sorted_by_name_set,
      :Image, id_in_set: sorted_by_name_set, order_by: :original_name
    )
  end

  def test_image_with_observations_of_name
    params = { lookup: [names(:fungi).id] }
    expects = Image.joins(:observations).distinct.
              merge(Observation.names(**params)).order_by_default
    assert_image_obs_query(expects, names: params)

    expects = [images(:connected_coprinus_comatus_image).id]
    assert_image_obs_query(
      expects, names: { lookup: [names(:coprinus_comatus).id] }
    )

    expects = [images(:agaricus_campestris_image).id]
    assert_image_obs_query(
      expects, names: { lookup: [names(:agaricus_campestris).id] }
    )

    assert_image_obs_query([], names: { lookup: [names(:conocybe_filaris).id] })
  end

  def test_image_with_observations_of_children
    expects = [images(:agaricus_campestris_image).id]
    params = { lookup: [names(:agaricus).id], include_subtaxa: true }
    assert_image_obs_query(expects, names: params)
    expects = Image.joins(:observations).distinct.
              merge(Observation.names(**params)).order_by_default
    assert_image_obs_query(expects, names: params)
  end
end
