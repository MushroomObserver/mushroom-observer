# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::SpeciesListsTest < UnitTestCase
  include API2Extensions

  # ---------------------------------
  #  :section: SpeciesList Requests
  # ---------------------------------

  def params_get(**)
    { method: :get, action: :species_list }.merge(**)
  end

  def spl_sample
    @spl_sample ||= SpeciesList.all.sample
  end

  def test_getting_species_lists
    assert_api_pass(params_get(id: spl_sample.id))
    assert_api_results([spl_sample])
  end

  def test_getting_species_lists_created_at
    spls = SpeciesList.created_on("2012-07-06")
    assert_not_empty(spls)
    assert_api_pass(params_get(created_at: "2012-07-06"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_updated_at
    spls = SpeciesList.where(SpeciesList[:updated_at].year.eq(2008))
    assert_not_empty(spls)
    assert_api_pass(params_get(updated_at: "2008"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_user
    spls = SpeciesList.where(user: rolf)
    assert_not_empty(spls)
    assert_api_pass(params_get(user: "rolf"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_date
    spls = SpeciesList.where(SpeciesList[:when] >= "2006-03-01").
           where(SpeciesList[:when] <= "2006-03-02")
    assert_not_empty(spls)
    assert_api_pass(params_get(date: "2006-03-01-2006-03-02"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_name
    obses = Observation.where(name: names(:fungi))
    spls = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(spls)
    assert_api_pass(params_get(name: "Fungi"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_name_include_synonyms
    obs1 = Observation.create!(user: rolf, when: Time.zone.now,
                               where: locations(:burbank),
                               name: names(:lactarius_alpinus))
    obs2 = Observation.create!(user: rolf, when: Time.zone.now,
                               where: locations(:burbank),
                               name: names(:lactarius_alpigenes))
    obs1.species_lists << species_lists(:first_species_list)
    obs2.species_lists << species_lists(:first_species_list)
    obs2.species_lists << species_lists(:another_species_list)
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    ssp_lists = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert(ssp_lists.length > 1)
    assert_api_pass(params_get(synonyms_of: "Lactarius alpinus"))
    assert_api_results(ssp_lists)
    assert_api_pass(
      params_get(name: "Lactarius alpinus", include_synonyms: "yes")
    )
    assert_api_results(ssp_lists)
  end

  def test_getting_species_lists_name_include_subtaxa
    assert_blank(
      Observation.where(text_name: "Agaricus"),
      "Tests won't work if there's already an Observation for genus Agaricus"
    )
    obses = Observation.names_like("Agaricus")
    ssp_lists = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(ssp_lists)
    agaricus = Name.where(text_name: "Agaricus").first # (an existing autonym)
    agaricus_obs = Observation.create(name: agaricus, user: rolf)
    agaricus_genus_list = SpeciesList.create!(
      title: "Agaricus Genus Obses", location: locations(:albion), user: rolf
    )
    agaricus_obs.species_lists << agaricus_genus_list

    assert_api_pass(params_get(children_of: "Agaricus"))
    assert_api_results(ssp_lists)
    assert_api_pass(params_get(name: "Agaricus", include_subtaxa: "yes"))
    assert_api_results(ssp_lists << agaricus_genus_list)
  end

  def test_getting_species_lists_location
    spls = SpeciesList.where(location: locations(:no_mushrooms_location))
    assert_not_empty(spls)
    assert_api_pass(params_get(location: "No Mushrooms"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_project
    proj1 = projects(:bolete_project)
    proj2 = projects(:two_list_project)
    spls = [proj1, proj2].map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(spls)
    assert_api_pass(params_get(project: "#{proj1.id}, #{proj2.id}"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_has_notes
    with    = SpeciesList.where(SpeciesList[:notes].not_blank)
    without = SpeciesList.where(SpeciesList[:notes].blank)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params_get(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_notes: "no"))
    assert_api_results(without)
  end

  def test_getting_species_lists_has_comments
    x = Comment.create(user: dick, target: spl_sample, summary: "test",
                       comment: "double dare you to reiterate this comment!")
    x.save
    assert_api_pass(params_get(has_comments: "yes"))
    assert_api_results([spl_sample])

    assert_api_pass(params_get(comments_has: "double dare"))
    assert_api_results([spl_sample])
  end

  def test_getting_species_lists_title_has
    spls = SpeciesList.where(SpeciesList[:title].matches("%mysteries%"))
    assert_not_empty(spls)
    assert_api_pass(params_get(title_has: "mysteries"))
    assert_api_results(spls)
  end

  def test_getting_species_lists_notes_has
    spls = SpeciesList.where(SpeciesList[:notes].matches("%skunk%"))
    assert_not_empty(spls)
    assert_api_pass(params_get(notes_has: "skunk"))
    assert_api_results(spls)
  end

  def test_creating_species_lists
    @user     = rolf
    @title    = "Maximal New Species List"
    @date     = Date.parse("2017-11-17")
    @location = locations(:burbank)
    @where    = locations(:burbank).name
    @notes    = "some notes"
    params = {
      method: :post,
      action: :species_list,
      api_key: @api_key.key,
      title: @title,
      date: "2017-11-17",
      location: @location.id,
      notes: @notes
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:title))
    assert_api_fail(params.merge(title: SpeciesList.first.title))
    assert_api_fail(params.merge(location: "bogus location"))
    assert_api_pass(params)
    assert_last_species_list_correct

    @title    = "Minimal New Species List"
    @date     = Time.zone.today
    @location = Location.unknown
    @where    = Location.unknown.name
    @notes    = nil
    params = {
      method: :post,
      action: :species_list,
      api_key: @api_key.key,
      title: @title
    }
    assert_api_pass(params)
    assert_last_species_list_correct

    @title    = "New Species List with Undefined Location"
    @date     = Time.zone.today
    @location = nil
    @where    = "Bogus, Arkansas, USA"
    @notes    = nil
    params = {
      method: :post,
      action: :species_list,
      api_key: @api_key.key,
      title: @title,
      location: @where
    }
    assert_api_pass(params)
    assert_last_species_list_correct
  end

  def test_patching_species_lists
    rolfs_spl = species_lists(:first_species_list)
    marys_spl = species_lists(:unknown_species_list)
    assert_not(marys_spl.can_edit?(rolf))
    @user     = rolf
    @title    = "New Title"
    @date     = Date.parse("2017-11-17")
    @location = locations(:mitrula_marsh)
    @where    = locations(:mitrula_marsh).name
    @notes    = "new notes"
    params = {
      method: :patch,
      action: :species_list,
      api_key: @api_key.key,
      id: rolfs_spl.id,
      set_title: @title,
      set_date: "2017-11-17",
      set_location: @location.display_name,
      set_notes: @notes
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: marys_spl.id))
    assert_api_fail(
      params.merge(set_title: SpeciesList.reorder(id: :asc).first.title)
    )
    assert_api_fail(params.merge(set_location: "bogus location"))
    assert_api_fail(params.merge(set_title: ""))
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_location: ""))
    assert_api_pass(params)
    assert_last_species_list_correct(rolfs_spl.reload)
  end

  def test_deleting_species_lists
    rolfs_spl = species_lists(:first_species_list)
    marys_spl = species_lists(:unknown_species_list)
    params = {
      method: :delete,
      action: :species_list,
      api_key: @api_key.key
    }
    assert_api_fail(params.merge(id: marys_spl.id))
    assert_api_pass(params.merge(id: rolfs_spl.id))
    assert_not_nil(SpeciesList.safe_find(marys_spl.id))
    assert_nil(SpeciesList.safe_find(rolfs_spl.id))
  end
end
