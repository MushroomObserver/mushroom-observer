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

    Observation.create!(name: names(:agaricus),
                        user: dick)
    assert_names_equal(names(:agaricus),
                       Observation.last.name)
    assert_users_equal(dick, Observation.last.user)
    data = Checklist::ForUser.new(dick)
    assert_equal(before_num_species, data.num_species)

    Observation.create!(name: names(:lactarius_kuehneri),
                        user: dick)
    data = Checklist::ForUser.new(dick)
    after_num_genera = data.num_genera
    after_num_species = data.num_species

    assert_equal(before_num_genera + 2, after_num_genera)
    assert_equal(before_num_species + 1, after_num_species)
    Observation.create!(name: names(:lactarius_subalpinus),
                        user: dick)
    Observation.create!(name: names(:lactarius_alpinus),
                        user: dick)
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
    # Ensure location coordinates are cached for bounding box matching
    obs.update_columns(
      location_lat: obs.location.center_lat,
      location_lng: obs.location.center_lng
    )
    proj.observations << obs
    data = Checklist::ForProject.new(proj, obs.location)
    assert_equal(1, data.num_taxa)
  end

  # Test that checklist uses bounding box matching, not exact location match
  def test_checklist_for_project_uses_bounding_box_matching
    proj = projects(:bolete_project)
    target_location = locations(:albion)

    # Create observation with exact location match
    obs_exact = Observation.create!(
      name: names(:coprinus_comatus),
      user: mary,
      location: target_location,
      when: Time.zone.now
    )
    proj.observations << obs_exact

    # Create observation with GPS coords inside bounding box but different
    # location_id
    obs_gps_inside = Observation.create!(
      name: names(:coprinus_comatus),
      user: mary,
      location: locations(:burbank), # Different location
      lat: target_location.center_lat, # But GPS inside albion's box
      lng: target_location.center_lng,
      when: Time.zone.now
    )
    proj.observations << obs_gps_inside

    data = Checklist::ForProject.new(proj, target_location)

    # Both observations should be counted (bounding box matching)
    assert_equal(
      2, data.counts["Coprinus comatus"],
      "Checklist should count observations with GPS coords inside bounding " \
      "box, not just exact location matches"
    )
  end

  def test_checklist_for_project_separates_unobserved_targets
    proj = projects(:rare_fungi_project)
    # Project has target names but no observations
    data = Checklist::ForProject.new(proj)

    # Unobserved targets land in a separate bucket, not in `taxa`.
    target_text_names = proj.target_names.map(&:text_name)
    unobserved_names = data.unobserved_target_taxa.pluck(0)
    assert_equal(target_text_names.sort, unobserved_names.sort)
    assert_empty(data.taxa, "Observed taxa should be empty with no obs")

    # Counts hash still seeds target names at 0 so link labels show "(0)".
    target_text_names.each do |tn|
      assert_equal(0, data.counts[tn])
    end

    assert_equal(proj.target_name_ids.sort, data.target_name_ids.sort)
  end

  def test_checklist_for_project_target_names_with_observations
    proj = projects(:rare_fungi_project)
    # Add an observation for one of the target names
    obs = Observation.create!(
      name: names(:coprinus_comatus),
      user: users(:rolf),
      when: Time.zone.now
    )
    proj.observations << obs

    data = Checklist::ForProject.new(proj)

    # Observed target name has count > 0 and appears in taxa.
    assert_operator(data.counts["Coprinus comatus"], :>, 0)
    assert_includes(data.taxa.pluck(0), "Coprinus comatus")

    # Unobserved target goes to the unobserved bucket, not taxa.
    assert_equal(0, data.counts["Agaricus campestris"])
    assert_includes(data.unobserved_target_taxa.pluck(0), "Agaricus campestris")
    assert_not_includes(data.taxa.pluck(0), "Agaricus campestris")
  end

  # ==========================================================================
  # Issue #4128 — Summary Line 1: target-name observation counts
  # ==========================================================================

  # L1-1: 2 targets, 1 observed directly, 1 not.
  def test_num_targets_observed_direct_match
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:coprinus_comatus))

    data = Checklist::ForProject.new(proj)
    assert_equal(2, data.num_targets)
    assert_equal(1, data.num_targets_observed)
    assert_equal(1, data.num_targets_unobserved)
  end

  # L1-2/L1-3: Observation of a synonym (not the target itself) counts
  # the target as observed.
  def test_num_targets_observed_via_synonym
    proj = projects(:rare_fungi_project)
    # macrolepiota_rachodes and macrolepiota_rhacodes share a synonym group
    add_target(proj, names(:macrolepiota_rachodes))
    proj.observations << obs_of(names(:macrolepiota_rhacodes))

    data = Checklist::ForProject.new(proj)
    # 3 targets now (the 2 rare_fungi + macrolepiota_rachodes);
    # macrolepiota_rachodes is observed via its synonym.
    assert_equal(3, data.num_targets)
    assert_equal(1, data.num_targets_observed)
    assert_includes(data.unobserved_target_taxa.pluck(0),
                    "Coprinus comatus")
    assert_not_includes(data.unobserved_target_taxa.pluck(0),
                        "Macrolepiota rachodes")
  end

  # L1-4: Targets exist, zero observations → all unobserved.
  def test_num_targets_observed_no_observations
    proj = projects(:rare_fungi_project)

    data = Checklist::ForProject.new(proj)
    assert_equal(0, data.num_targets_observed)
    assert_equal(2, data.num_targets_unobserved)
  end

  # L1-5: Observation of a synonym NOT attached to project.observations
  # does not count the target as observed.
  def test_synonym_obs_outside_project_does_not_count
    proj = projects(:rare_fungi_project)
    add_target(proj, names(:macrolepiota_rachodes))
    # Create the obs but DO NOT add it to project.observations
    obs_of(names(:macrolepiota_rhacodes))

    data = Checklist::ForProject.new(proj)
    assert_equal(0, data.num_targets_observed)
    assert_includes(data.unobserved_target_taxa.pluck(0),
                    "Macrolepiota rachodes")
  end

  # ==========================================================================
  # Issue #4128 — Summary Line 2: species/higher counts, synonyms collapsed
  # ==========================================================================

  # L2-1: Two observed species sharing synonym_id → species count = 1.
  def test_num_species_observed_collapses_synonyms
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:macrolepiota_rachodes))
    proj.observations << obs_of(names(:macrolepiota_rhacodes))

    data = Checklist::ForProject.new(proj)
    assert_equal(1, data.num_species_observed)
    assert_equal(0, data.num_higher_level_observed)
    # Both still appear as rows in the species-level panel.
    assert_equal(2, data.species_level_observed_taxa.size)
  end

  # L2-2: Disjoint species + genera counts, no overlap with "genus of species".
  def test_num_species_and_higher_are_disjoint
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:coprinus_comatus)) # species
    proj.observations << obs_of(names(:agaricus_campestris)) # species
    proj.observations << obs_of(names(:agaricus)) # Genus

    data = Checklist::ForProject.new(proj)
    assert_equal(2, data.num_species_observed)
    assert_equal(1, data.num_higher_level_observed)
  end

  # L2-5: No observations → both counts are 0.
  def test_summary_counts_with_no_observations
    data = Checklist::ForProject.new(projects(:rare_fungi_project))
    assert_equal(0, data.num_species_observed)
    assert_equal(0, data.num_higher_level_observed)
  end

  # L2-6: Group rank is classified as higher-level.
  def test_group_rank_is_higher_level
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:coprinus_comatus))
    proj.observations << obs_of(names(:boletus_edulis_group))

    data = Checklist::ForProject.new(proj)
    assert_equal(1, data.num_species_observed)
    assert_equal(1, data.num_higher_level_observed)
    assert_includes(data.higher_level_observed_taxa.pluck(0),
                    "Boletus edulis group")
  end

  # L2-7: Infrageneric ranks (Subgenus, Section, etc.) are higher-level.
  def test_infrageneric_rank_is_higher_level
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:coprinus_comatus))
    proj.observations << obs_of(names(:amanita_subgenus_lepidella))

    data = Checklist::ForProject.new(proj)
    assert_equal(1, data.num_species_observed)
    assert_equal(1, data.num_higher_level_observed)
    assert_includes(data.higher_level_observed_taxa.pluck(0),
                    "Amanita subg. Lepidella")
  end

  # ==========================================================================
  # Issue #4128 — Panel contents
  # ==========================================================================

  # P-1: Unobserved target appears in unobserved panel only.
  def test_unobserved_target_in_unobserved_panel_only
    proj = projects(:rare_fungi_project)

    data = Checklist::ForProject.new(proj)
    names_in_unobserved = data.unobserved_target_taxa.pluck(0)
    assert_includes(names_in_unobserved, "Coprinus comatus")
    assert_not_includes(data.species_level_observed_taxa.pluck(0),
                        "Coprinus comatus")
    assert_not_includes(data.higher_level_observed_taxa.pluck(0),
                        "Coprinus comatus")
  end

  # P-5: Genus observation lands in higher-level panel.
  def test_genus_observation_in_higher_panel
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:agaricus))

    data = Checklist::ForProject.new(proj)
    assert_includes(data.higher_level_observed_taxa.pluck(0), "Agaricus")
    assert_not_includes(data.species_level_observed_taxa.pluck(0), "Agaricus")
  end

  # P-7: Variety rank lands in species-level panel.
  def test_variety_observation_in_species_panel
    proj = projects(:rare_fungi_project)
    proj.observations << obs_of(names(:amanita_boudieri_var_beillei))

    data = Checklist::ForProject.new(proj)
    species_names = data.species_level_observed_taxa.pluck(0)
    assert_includes(species_names, "Amanita boudieri var. beillei")
    assert_equal(1, data.num_species_observed)
  end

  private

  def obs_of(name)
    Observation.create!(name: name, user: users(:rolf), when: Time.zone.now)
  end

  def add_target(project, name)
    ProjectTargetName.create!(project: project, name: name)
  end

  def test_checklist_for_project_include_sub_locations
    proj = projects(:bolete_project)
    california = locations(:california)
    albion = locations(:albion) # "Albion, California, USA"

    # Add observation in Albion (a sub-location of California)
    obs = Observation.create!(
      name: names(:coprinus_comatus),
      user: mary,
      location: albion,
      when: Time.zone.now
    )
    proj.observations << obs

    # With include_sub_locations: name suffix match
    data_with = Checklist::ForProject.new(
      proj, california, include_sub_locations: true
    )

    assert_operator(
      data_with.num_taxa, :>=, 1,
      "Sub-location obs should appear with include_sub_locations"
    )
    taxa_names = data_with.taxa.pluck(0)
    assert_includes(taxa_names, "Coprinus comatus")
  end

  # Verify suffix matching excludes GPS-overlap observations
  # (the bug that #4126 fixes: e.g., Ohio obs inside WV box)
  def test_checklist_sub_locations_excludes_gps_overlap
    proj = projects(:bolete_project)
    california = locations(:california)

    # Create a non-California location with GPS inside CA box
    nevada_loc = Location.create!(
      name: "Reno, Nevada, USA",
      scientific_name: "USA, Nevada, Reno",
      north: 39.6, south: 39.4, east: -119.7, west: -119.9,
      user: mary
    )
    overlap_obs = Observation.create!(
      name: names(:boletus_edulis),
      user: mary, location: nevada_loc,
      lat: 39.5, lng: -119.8, when: Time.zone.now
    )
    proj.observations << overlap_obs

    # Without sub_locations (GPS bounding box): should include it
    data_gps = Checklist::ForProject.new(proj, california)
    assert_includes(
      data_gps.taxa.pluck(0), "Boletus edulis",
      "GPS-box match should include obs inside CA bounding box"
    )

    # With sub_locations (name suffix): should exclude it
    data_suffix = Checklist::ForProject.new(
      proj, california, include_sub_locations: true
    )
    assert_not_includes(
      data_suffix.taxa.pluck(0), "Boletus edulis",
      "Suffix match should exclude Nevada obs despite GPS overlap"
    )
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
