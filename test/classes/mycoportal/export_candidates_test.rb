# frozen_string_literal: true

require("test_helper")

class Mycoportal::ExportCandidatesTest < UnitTestCase
  def test_new_observation_ids_includes_high_confidence_obs
    obs = create_observation(vote_cache: 3.0)

    assert_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_excludes_low_confidence_obs
    obs = create_observation(vote_cache: 1.0)

    assert_not_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_excludes_excluded_name
    obs = create_observation(vote_cache: 3.0, name: excluded_name)

    assert_not_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_excludes_non_fungal_kingdom
    obs = create_observation(vote_cache: 3.0, name: plant_name)

    assert_not_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_excludes_empty_observation
    obs = create_observation(vote_cache: 3.0, name: names(:fungi),
                             where: nil, location: nil)

    assert_not_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_includes_unnamed_obs_with_content
    # Empty except for notes -- not "empty" because it has content.
    obs = create_observation(vote_cache: 3.0, name: names(:fungi),
                             notes: { Other: "Found under oak" })

    assert_includes(candidates.new_observation_ids, obs.id)
  end

  def test_new_observation_ids_excludes_already_exported_obs
    obs = create_observation(vote_cache: 3.0)
    export_obs!(obs, last_synced_at: 1.hour.ago)

    assert_not_includes(candidates.new_observation_ids, obs.id)
  end

  def test_updated_observation_ids_includes_obs_changed_since_export
    obs = create_observation(vote_cache: 3.0)
    export_obs!(obs, last_synced_at: 1.hour.ago)

    assert_includes(candidates.updated_observation_ids, obs.id)
  end

  def test_updated_observation_ids_excludes_obs_unchanged_since_export
    obs = create_observation(vote_cache: 3.0)
    export_obs!(obs, last_synced_at: 1.hour.from_now)

    assert_not_includes(candidates.updated_observation_ids, obs.id)
  end

  private

  def candidates
    Mycoportal::ExportCandidates.new
  end

  def create_observation(vote_cache:, name: names(:coprinus_comatus),
                         where: "anywhere", location: nil, notes: {})
    Observation.create!(
      user: rolf, when: Time.zone.today, where: where, location: location,
      name_id: name.id, vote_cache: vote_cache, notes: notes
    )
  end

  def export_obs!(obs, last_synced_at:)
    ExternalLink.create!(
      user: rolf, target_type: "Observation", target_id: obs.id,
      external_site: ExternalSite.mycoportal, relationship: :export,
      last_synced_at: last_synced_at
    )
  end

  def excluded_name
    @excluded_name ||= Name.create!(
      user: rolf, rank: "Species", text_name: "Undetermined", author: "",
      search_name: "Undetermined", display_name: "Undetermined"
    )
  end

  def plant_name
    @plant_name ||= Name.create!(
      user: rolf, rank: "Species", text_name: "Zea mays", author: "L.",
      search_name: "Zea mays L.", display_name: "**__Zea mays__** L.",
      classification: "Domain: _Eukarya_\r\nKingdom: _Plantae_\r\n"
    )
  end
end
