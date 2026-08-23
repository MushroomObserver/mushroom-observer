# frozen_string_literal: true

require("test_helper")

# Observation::Companion -- the editable twin Edit opens for a
# read-only reflection (#4214).
class Observation::CompanionTest < UnitTestCase
  def setup
    super
    @reflection = observations(:imported_inat_obs)
    @reflection.update_column(:reflected_at, Time.zone.now)
    @user = @reflection.user
  end

  def test_create_copies_snapshot_shares_images_and_joins_projects
    @reflection.update!(lat: 41.5, lng: -70.5, alt: 12, gps_hidden: true,
                        notes: { Other: "imported notes" },
                        collector: "Someone Else", collector_user_id: nil)
    @reflection.images << images(:in_situ_image)
    @reflection.update!(thumb_image: images(:in_situ_image))
    project = projects(:eol_project)
    project.add_observation(@reflection)

    companion = Observation::Companion.new(@reflection, @user).create

    assert_not(companion.reflection?)
    assert_equal(@user.id, companion.user_id)
    assert_equal("mo_website", companion.source)
    Observation::Companion::SNAPSHOT.each do |field|
      assert_equal(@reflection.send(field), companion.send(field),
                   "#{field} should be copied")
    end
    assert_equal(@reflection.name_id, companion.name_id)
    assert_equal(@reflection.name_id,
                 companion.namings.first.name_id)
    assert_equal([images(:in_situ_image).id], companion.image_ids)
    assert_equal(images(:in_situ_image).id, companion.thumb_image_id)
    assert_equal([project.id], companion.project_ids)
    assert_equal(@reflection.reload.occurrence_id, companion.occurrence_id)
    assert_equal(@reflection.id,
                 companion.occurrence.primary_observation_id)
  end

  def test_create_joins_the_reflections_existing_occurrence
    sibling = observations(:minimal_unknown_obs)
    occurrence = Occurrence.create!(user: @user,
                                    primary_observation: @reflection)
    @reflection.update!(occurrence: occurrence)
    sibling.update!(occurrence: occurrence, reflected_at: Time.zone.now)

    companion = Observation::Companion.new(@reflection, @user).create

    assert_equal(occurrence.id, companion.occurrence_id)
    assert_equal(@reflection.id, occurrence.reload.primary_observation_id)
    assert_equal(3, occurrence.observations.count)
  end

  def test_existing_finds_an_editable_non_reflection_member
    builder = Observation::Companion.new(@reflection, @user)
    assert_nil(builder.existing)

    companion = builder.create

    assert_equal(companion, builder.existing)
    # A reflection sibling is not a companion.
    companion.update_column(:reflected_at, Time.zone.now)
    assert_nil(Observation::Companion.new(@reflection, @user).existing)
  end

  def test_create_refuses_a_full_occurrence
    occurrence = Occurrence.create!(user: @user,
                                    primary_observation: @reflection)
    @reflection.update!(occurrence: occurrence)
    members = Observation.where.not(id: @reflection.id).
              limit(Occurrence::MAX_OBSERVATIONS - 1)
    members.each { |obs| obs.update_columns(occurrence_id: occurrence.id) }

    assert_raises(ActiveRecord::RecordInvalid) do
      Observation::Companion.new(@reflection, @user).create
    end
  end
end
