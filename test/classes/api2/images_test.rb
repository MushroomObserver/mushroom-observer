# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::ImagesTest < UnitTestCase
  include API2Extensions

  def test_basic_image_get
    do_basic_get_test(Image)
  end

  # ---------------------------
  #  :section: Image Requests
  # ---------------------------

  def params_get(**)
    { method: :get, action: :image }.merge(**)
  end

  def in_situ_img
    @in_situ_img ||= images(:in_situ_image)
  end

  def turned_over_img
    @turned_over_img ||= images(:turned_over_image)
  end

  def pretty_img
    @pretty_img ||= images(:peltigera_image)
  end

  def noteless_img
    @noteless_img ||= images(:rolf_profile_image)
  end

  def test_getting_images
    img = Image.all.sample
    assert_api_pass(params_get(id: img.id))
    assert_api_results([img])
  end

  def img_samples
    @img_samples ||= Image.all.sample(12)
  end

  def test_getting_images_ids
    assert_api_pass(params_get(id: img_samples.map(&:id).join(",")))
    assert_api_results(img_samples)
  end

  def test_getting_images_created_at
    assert_api_pass(params_get(created_at: "2006"))
    assert_api_results(Image.where(Image[:created_at].year.eq(2006)))
  end

  def test_getting_images_updated_at
    assert_api_pass(params_get(updated_at: "2006-05-22"))
    assert_api_results(Image.created_on("2006-05-22"))
  end

  def test_getting_images_date
    assert_api_pass(params_get(date: "2007-03"))
    assert_api_results(
      Image.where(Image[:when].year.eq(2007).and(Image[:when].month.eq(3)))
    )
  end

  def test_getting_images_user
    assert_api_pass(params_get(user: "#{mary.id},#{katrina.id}"))
    assert_api_results(Image.where(user: [mary, katrina]))
  end

  def test_getting_images_name
    name = names(:agaricus_campestris)
    imgs = name.observations.map(&:images).flatten
    assert_not_empty(imgs)
    assert_api_pass(params_get(name: "Agaricus campestris"))
    assert_api_results(imgs)
  end

  def test_getting_images_include_synonyms
    name = names(:agaricus_campestris)
    imgs = name.observations.map(&:images).flatten
    name2 = names(:agaricus_campestros)
    synonym = Synonym.create!
    name.update!(synonym: synonym)
    name2.update!(synonym: synonym)
    assert_api_pass(params_get(synonyms_of: "Agaricus campestros"))
    assert_api_results(imgs)
    assert_api_pass(
      params_get(name: "Agaricus campestros", include_synonyms: "yes")
    )
    assert_api_results(imgs)
  end

  def test_getting_images_include_subtaxa
    name = names(:agaricus_campestris)
    imgs = name.observations.map(&:images).flatten
    agaricus = Name.where(text_name: "Agaricus").first # (an existing autonym)
    agaricus_img = Image.create(
      # add notes to avoid breaking later, brittle assertion
      notes: "Agaricus image", user: rolf
    )
    Observation.create(
      name: agaricus, images: [agaricus_img], thumb_image: agaricus_img,
      user: rolf
    )
    assert_api_pass(params_get(children_of: "Agaricus"))
    assert_api_results(imgs)
    assert_api_pass(params_get(name: "Agaricus", include_subtaxa: "yes"))
    assert_api_results(imgs << agaricus_img)
  end

  def test_getting_images_location
    burbank = locations(:burbank)
    imgs = Image.locations(burbank)
    assert_not_empty(imgs)
    assert_api_pass(params_get(location: burbank.id))
    assert_api_results(imgs)
  end

  def test_getting_images_observation
    obs1 = observations(:detailed_unknown_obs)
    obs2 = observations(:coprinus_comatus_obs)
    assert_not_empty(obs1.images)
    assert_not_empty(obs2.images)
    assert_api_pass(params_get(observation: "#{obs1.id},#{obs2.id}"))
    assert_api_results(obs1.images + obs2.images)
  end

  def test_getting_images_project
    project = projects(:bolete_project)
    assert_not_empty(project.images)
    assert_api_pass(params_get(project: "Bolete Project"))
    assert_api_results(project.images)
  end

  def test_getting_images_species_list
    spl = species_lists(:unknown_species_list)
    assert_api_pass(params_get(species_list: spl.title))
    assert_api_results([in_situ_img, turned_over_img])
  end

  def test_getting_images_has_observation
    attached   = Image.select { |i| i.observations.any? }
    unattached = Image.all - attached
    assert_not_empty(attached)
    assert_not_empty(unattached)
    assert_api_pass(params_get(has_observation: "yes"))
    assert_api_results(attached)
    # This query doesn't work, no way to negate join.
    # assert_api_pass(params_get(has_observation: "no"))
    # assert_api_results(unattached)
  end

  def test_getting_images_size
    imgs = Image.where((Image[:width] >= 1280).or(Image[:height] >= 1280))
    assert_empty(imgs)
    imgs = Image.where((Image[:width] >= 960).or(Image[:height] >= 960))
    assert_not_empty(imgs)
    assert_api_pass(params_get(size: "huge"))
    assert_api_results([])
    assert_api_pass(params_get(size: "large"))
    assert_api_results(imgs)
  end

  def test_getting_images_content_type
    in_situ_img.update!(content_type: "image/png")
    assert_api_pass(params_get(content_type: "png"))
    assert_api_results([in_situ_img])
  end

  def test_getting_images_has_notes
    assert_api_pass(params_get(has_notes: "no"))
    assert_api_results([noteless_img])
  end

  def test_getting_images_notes_has
    assert_api_pass(params_get(notes_has: "pretty"))
    assert_api_results([pretty_img])
  end

  def test_getting_images_copyright_holder_has
    assert_api_pass(params_get(copyright_holder_has: "Insil Choi"))
    assert_api_results(
      Image.where(Image[:copyright_holder].matches("%insil choi%"))
    )
    assert_api_pass(params_get(copyright_holder_has: "Nathan"))
    assert_api_results(
      Image.where(Image[:copyright_holder].matches("%nathan%"))
    )
  end

  def test_getting_images_license
    pd = licenses(:publicdomain)
    assert_api_pass(params_get(license: pd.id))
    assert_api_results(Image.where(license: pd))
  end

  def test_getting_images_has_votes
    assert_api_pass(params_get(has_votes: "yes"))
    assert_api_results(Image.where(Image[:vote_cache].not_eq(nil)))
    assert_api_pass(params_get(has_votes: "no"))
    assert_api_results(Image.where(Image[:vote_cache].eq(nil)))
  end

  def test_getting_images_quality
    assert_api_pass(params_get(quality: "2-3"))
    assert_api_results(Image.where(Image[:vote_cache] > 2.0))
    assert_api_pass(params_get(quality: "1-2"))
    assert_api_results([])
  end

  def test_getting_images_confidence
    imgs = Observation.where(Observation[:vote_cache] >= 2.0).
           map(&:images).flatten
    assert_not_empty(imgs)
    assert_api_pass(params_get(confidence: "2-3"))
    assert_api_results(imgs)
  end

  def test_getting_images_ok_for_export
    pretty_img.update!(ok_for_export: false)
    assert_api_pass(params_get(ok_for_export: "no"))
    assert_api_results([pretty_img])
  end

  # REVIEW: IMO this test should fail. This should be considered an invalid use
  # of the API `name` param (which corresponds to Query `names`). `names` wants
  # an array of ids, with lookup-by-string as a last resort. This API query
  # should instead have been sent as two queries: a pattern search returning
  # ids, and then a query for subtaxa via an id.
  # def test_two_agaricus_bug
  #   name = names(:agaricus_campestris) # the only Agaricus species with images
  #   imgs = name.observations.map(&:images).flatten

  #   # Create 2nd Agaricus.  There's an existing Agaricus without and author.
  #   # The API2 and Query parsers were resolving "Agaricus" to the one without
  #   # an author thinking that was an exact match, instead of resolving to both
  #   # versions like it should.
  #   agaricus = Name.create(
  #     rank: Name.ranks[:Genus], text_name: "Agaricus",  author: "L.",
  #     search_name: "Agaricus L.", sort_name: "Agaricus  L.",
  #     display_name: "**__Agaricus__** L.", user: rolf
  #   )
  #   assert_equal(2, Name.where(text_name: "Agaricus").count)

  #   agaricus_img = Image.create(user: rolf)
  #   Observation.create(
  #     name: agaricus, images: [agaricus_img], thumb_image: agaricus_img,
  #     user: rolf
  #   )

  #   assert_api_pass(
  #     method: :get, action: :image, name: "Agaricus", include_subtaxa: "yes"
  #   )
  #   assert_api_results(imgs << agaricus_img)
  # end

  def test_posting_minimal_image
    setup_image_dirs
    @user   = rolf
    @proj   = nil
    @date   = Time.zone.today
    @copy   = @user.legal_name
    @notes  = ""
    @orig   = nil
    @width  = 407
    @height = 500
    @vote   = nil
    @obs    = nil
    params  = {
      method: :post,
      action: :image,
      api_key: @api_key.key,
      upload_file: Rails.root.join("test/images/sticky.jpg"),
      original_name: "strip_this"
    }
    assert_equal("toss", @user.keep_filenames)
    File.stub(:rename, true) do
      File.stub(:chmod, true) do
        api = API2.execute(params)
        assert_no_errors(api, "Errors while posting image")
        assert_obj_arrays_equal([Image.last],
                                api.results)
      end
    end
    assert_last_image_correct
  end

  def test_posting_maximal_image
    setup_image_dirs
    rolf.update(keep_filenames: "keep_and_show")
    rolf.reload
    @user   = rolf
    @proj   = projects(:eol_project)
    @date   = date("20120626")
    @copy   = "My Friend"
    @notes  = "These are notes.\nThey look like this.\n"
    @orig   = "sticky.png"
    @width  = 407
    @height = 500
    @vote   = 3
    @obs    = @user.observations.last
    params  = {
      method: :post,
      action: :image,
      api_key: @api_key.key,
      date: "20120626",
      notes: @notes,
      copyright_holder: " My Friend ",
      license: @user.license.id,
      vote: "3",
      observations: @obs.id,
      projects: @proj.id,
      upload_file: Rails.root.join("test/images/sticky.jpg"),
      original_name: @orig
    }
    File.stub(:rename, true) do
      File.stub(:chmod, true) do
        api = API2.execute(params)
        assert_no_errors(api, "Errors while posting image")
        assert_obj_arrays_equal([Image.last],
                                api.results)
      end
    end
    assert_last_image_correct
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:upload_file))
    assert_api_fail(params.merge(original_name: "x" * 1000))
    assert_api_fail(params.merge(vote: "-5"))

    obs = Observation.where(user: katrina).first
    assert_api_fail(params.merge(observations: obs.id.to_s))
    # Rolf is not a member of this project
    assert_api_fail(params.merge(projects: projects(:bolete_project).id.to_s))
  end

  def test_posting_image_via_url
    setup_image_dirs
    url = "https://mushroomobserver.org/images/thumb/459340.jpg"
    stub_request(:any, url).
      to_return(Rails.root.join("test/images/test_image.curl").read)
    params = {
      method: :post,
      action: :image,
      api_key: @api_key.key,
      upload_url: url
    }
    File.stub(:rename, false) do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting image")
      img = Image.last
      assert_obj_arrays_equal([img], api.results)
      actual = File.read(img.full_filepath(:full_size))
      expect = Rails.root.join("test/images/test_image.jpg").read
      assert_equal(expect, actual, "Uploaded image differs from original!")
    end
  end

  def test_patching_images
    rolf.update(keep_filenames: "keep_and_show")
    rolf.reload
    rolfs_img = images(:rolf_profile_image)
    marys_img = images(:in_situ_image)
    eol = projects(:eol_project)
    pd = licenses(:publicdomain)
    assert(rolfs_img.can_edit?(rolf))
    assert_not(marys_img.can_edit?(rolf))
    params = {
      method: :patch,
      action: :image,
      api_key: @api_key.key,
      set_date: "2012-3-4",
      set_notes: "new notes",
      set_copyright_holder: "new person",
      set_license: pd.id,
      set_original_name: "new name"
    }
    assert_api_fail(params.merge(id: marys_img.id))
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_license: ""))
    assert_api_pass(params.merge(id: rolfs_img.id))
    rolfs_img.reload
    assert_equal(Date.parse("2012-3-4"), rolfs_img.when)
    assert_equal("new notes", rolfs_img.notes)
    assert_equal("new person", rolfs_img.copyright_holder)
    assert_objs_equal(pd, rolfs_img.license)
    assert_equal("new name", rolfs_img.original_name)
    eol.images << marys_img
    marys_img.reload
    assert(marys_img.can_edit?(rolf))
    assert_api_pass(params.merge(id: marys_img.id))
    marys_img.reload
    assert_equal(Date.parse("2012-3-4"), marys_img.when)
    assert_equal("new notes", marys_img.notes)
    assert_equal("new person", marys_img.copyright_holder)
    assert_objs_equal(pd, marys_img.license)
    assert_equal("new name", marys_img.original_name)
  end

  def test_deleting_images
    rolfs_img = rolf.images.sample
    marys_img = mary.images.sample
    params = {
      method: :delete,
      action: :image,
      api_key: @api_key.key
    }
    assert_api_fail(params.merge(id: marys_img.id))
    assert_api_pass(params.merge(id: rolfs_img.id))
    assert_not_nil(Image.safe_find(marys_img.id))
    assert_nil(Image.safe_find(rolfs_img.id))
  end
end
