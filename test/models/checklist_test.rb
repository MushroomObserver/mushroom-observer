# frozen_string_literal: true

require("test_helper")

class ChecklistTest < UnitTestCase
  def katrinas_species
    ["Conocybe filaris"]
  end

  def rolfs_species
    [
      "Agaricus campestras", # these are not synonymized
      "Agaricus campestris",
      "Agaricus campestros",
      "Agaricus campestrus",
      "Boletus edulis",
      "Coprinus comatus",
      "Stereum hirsutum",
      "Strobilurus diminutivus",
      "Tubaria furfuracea"
    ]
  end

  def dicks_species
    [
      "Boletus edulis"
    ]
  end

  def genera(species)
    species.map { |name| name.split(" ", 2).first }.uniq
  end

  def just_names(species)
    species.pluck(0)
  end

  def test_checklist_for_site
    data = Checklist::ForSite.new
    obs_with_genus = Observation.joins(:name).
                     where("names.`rank` <= #{Name.ranks[:Genus]}")
    names = obs_with_genus.map { |obs| obs.name.text_name }.uniq.sort
    all_genera = genera(names).uniq
    assert_equal(all_genera, data.genera)

    species_obs = Observation.joins(:name).
                  where("names.`rank` = #{Name.ranks[:Species]}")
    species_names = species_obs.map { |obs| obs.name.text_name }.uniq.sort
    assert_equal(species_names, just_names(data.species))
  end

  def test_checklist_for_users
    data = Checklist::ForUser.new(mary)
    assert(data.num_genera >= 1)
    assert_equal(0, data.num_species)
    assert_equal([], data.species)

    data = Checklist::ForUser.new(katrina)
    assert(data.num_genera >= 1)
    assert(data.num_species >= 1)
    assert(genera(katrinas_species) - data.genera == [])
    assert(katrinas_species - just_names(data.species) == [])

    data = Checklist::ForUser.new(rolf)
    assert_equal(7, data.num_genera)

    expect = Name.joins(observations: :user).
             where("observations.user_id = #{users(:rolf).id}
                    AND names.`rank` = #{Name.ranks[:Species]}").
             distinct.size
    assert_equal(expect, data.num_species)

    assert(genera(rolfs_species) - data.genera == [])
    assert_equal(rolfs_species, just_names(data.species))

    User.current = dick
    before_data = Checklist::ForUser.new(dick)
    before_num_species = before_data.num_species
    before_num_genera = before_data.num_genera

    Observation.create!(name: names(:agaricus))
    assert_names_equal(names(:agaricus), Observation.reorder(id: :asc).last.name)
    assert_users_equal(dick, Observation.reorder(id: :asc).last.user)
    data = Checklist::ForUser.new(dick)
    assert_equal(before_num_species, data.num_species)

    Observation.create!(name: names(:lactarius_kuehneri))
    data = Checklist::ForUser.new(dick)
    after_num_genera = data.num_genera
    after_num_species = data.num_species

    assert_equal(before_num_genera + 2, after_num_genera)
    assert_equal(before_num_species + 1, after_num_species)
    Observation.create!(name: names(:lactarius_subalpinus))
    Observation.create!(name: names(:lactarius_alpinus))
    data = Checklist::ForUser.new(dick)
    assert_equal(after_num_genera, data.num_genera)
    assert_equal(after_num_species + 2, data.num_species)
  end

  def test_checklist_for_projects
    proj = projects(:bolete_project)
    data = Checklist::ForProject.new(proj)
    assert_equal(0, data.num_genera)
    assert_equal(0, data.num_species)
    assert_equal([], data.genera)
    assert_equal([], data.species)

    obs = observations(:coprinus_comatus_obs)
    proj.observations << obs
    data = Checklist::ForProject.new(proj)
    assert_equal(1, data.num_genera)
    assert_equal(1, data.num_species)
    assert_equal(["Coprinus"], data.genera)
    assert_equal([["Coprinus comatus", obs.name_id]], data.species)
  end

  def test_checklist_for_project_locations
    proj = projects(:bolete_project)
    proj.observations << observations(:trusted_hidden)
    obs = observations(:minimal_unknown_obs)
    proj.observations << obs
    data = Checklist::ForProject.new(proj, obs.location)
    assert_equal(1, data.num_taxa)
  end

  def test_checklist_for_species_lists
    list = species_lists(:unknown_species_list)
    data = Checklist::ForSpeciesList.new(list)
    assert_equal(0, data.num_genera)
    assert_equal(0, data.num_species)
    assert_equal([], data.genera)
    assert_equal([], data.species)

    obs = observations(:coprinus_comatus_obs)
    list.observations << obs
    data = Checklist::ForSpeciesList.new(list)
    assert_equal(1, data.num_genera)
    assert_equal(1, data.num_species)
    assert_equal(["Coprinus"], data.genera)
    assert_equal([["Coprinus comatus", obs.name_id]], data.species)
  end
end
