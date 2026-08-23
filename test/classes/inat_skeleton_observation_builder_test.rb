# frozen_string_literal: true

require("test_helper")

# Unit tests for Inat::SkeletonObservationBuilder (#4828): the minimal
# "counterpart" Observation built for an unlicensed import-others obs.
# Integration coverage against a real recorded iNat fixture (create_mo_name
# via the API, end-to-end job behavior) lives in
# test/jobs/inat_import_job_test.rb
# (test_job_creates_skeleton_for_unlicensed_obs_for_not_own_import); this
# file isolates the builder's own logic with an already-existing MO Name,
# so no Names API call is involved.
class InatSkeletonObservationBuilderTest < UnitTestCase
  include ActiveJob::TestHelper

  # Minimal stand-in for an ::Inat::Obs, exposing only what
  # Inat::SkeletonObservationBuilder and Inat::LeadNameResolver read.
  class FakeInatObs
    FAKE_INAT_ID = 87_654_321

    def initialize(name:, quality_grade: "needs_id", collector: "A Collector",
                   owner: { login: "danmorton", name: "Daniel Morton" },
                   lead_overrides: {})
      @name = name
      @quality_grade = quality_grade
      @collector = collector
      @owner_login = owner[:login]
      @owner_name = owner[:name]
      @provisional_name = lead_overrides[:provisional_name]
      @name_override = lead_overrides[:name_override]
    end

    attr_reader :name, :collector, :provisional_name, :name_override

    def when = Date.new(2024, 4, 29)
    def location = ::Location.find_by(name: "Albion, California, USA")
    def where = "Albion, California, USA"
    def lat = 44.0
    def lng = -123.0
    def gps_hidden = false # rubocop:disable Naming/PredicateMethod

    def [](key)
      { id: FAKE_INAT_ID, quality_grade: @quality_grade, license_code: nil,
        identifications: [],
        user: { login: @owner_login, name: @owner_name } }[key]
    end
  end

  def test_mo_observation_builds_minimal_skeleton
    name = names(:peltigera)
    builder = builder_for(name: name)

    obs = builder.mo_observation

    assert_equal(name.id, obs.name_id, "Wrong Name")
    assert_equal(Date.new(2024, 4, 29), obs.when, "Wrong date")
    assert_equal("Albion, California, USA", obs.where, "Wrong location")
    assert_equal("A Collector", obs.collector, "Wrong collector")
    assert(obs.placeholder?, "Skeleton obs should be flagged placeholder")
    assert(obs.reflection?,
           "Skeleton obs should be a reflection, so it's Sync-eligible")
    assert_equal(0, obs.images.length, "Skeleton should have no images")
    assert_equal(1, obs.namings.length, "Skeleton should have 1 naming")
    assert_equal(users(:rolf), obs.namings.first.user,
                 "Skeleton's naming should always be attributed to importer")
    assert_equal(obs.namings.first.id, obs.inat_stand_in_naming_id,
                 "Skeleton's Naming should be recorded as sync's stand-in")
    assert_naming_reason(obs)
    assert_placeholder_notes(obs)
    assert(
      ExternalLink.exists?(target: obs, external_site: ExternalSite.inaturalist,
                           external_id: FakeInatObs::FAKE_INAT_ID.to_s,
                           relationship: :import),
      "Skeleton should have an import ExternalLink to the iNat obs"
    )
    assert_equal(0, builder.unlicensed_obs)
    assert_equal(0, builder.skipped_images)
    assert_equal([], builder.created_image_ids)
  end

  # Regression: a skeleton must track the pure Leading ID (the community
  # taxon) even when the iNat obs also carries a "Species Name Override"
  # or "Provisional Species Name" observation field -- unlike a full
  # import, a skeleton has exactly one, un-attributed Naming, so honoring
  # either field would silently substitute a name nobody asked MO to
  # track.
  def test_mo_observation_ignores_name_override
    fake = FakeInatObs.new(name: names(:peltigera),
                           lead_overrides: { name_override: "Coprinus" })
    builder = Inat::SkeletonObservationBuilder.new(
      inat_obs: fake, user: users(:rolf),
      external_site: ExternalSite.inaturalist
    )

    obs = builder.mo_observation

    assert_equal(names(:peltigera), obs.name,
                 "Skeleton should track the community taxon, not an " \
                 "iNat 'Species Name Override' field")
  end

  def test_mo_observation_ignores_provisional_name
    fake = FakeInatObs.new(name: names(:peltigera),
                           lead_overrides: { provisional_name: "Coprinus" })
    builder = Inat::SkeletonObservationBuilder.new(
      inat_obs: fake, user: users(:rolf),
      external_site: ExternalSite.inaturalist
    )

    obs = builder.mo_observation

    assert_equal(names(:peltigera), obs.name,
                 "Skeleton should track the community taxon, not an " \
                 "iNat 'Provisional Species Name' field")
  end

  def test_mo_observation_destroys_persisted_observation_on_later_failure
    builder = builder_for(name: names(:peltigera))

    assert_no_difference("Observation.count",
                         "Failed to destroy incomplete Observation") do
      ObservationView.stub(:create!, ->(*) { raise("boom") }) do
        assert_raises(RuntimeError) { builder.mo_observation }
      end
    end
  end

  # A duplicate import ExternalLink attempt (the target already has one --
  # only one import link per target is allowed) fails validation and gets
  # logged, not raised.
  def test_create_import_link_logs_and_skips_a_duplicate
    skeleton = builder_for(name: names(:peltigera)).mo_observation
    duplicate_builder = builder_for(name: names(:peltigera))

    assert_nothing_raised do
      duplicate_builder.send(:create_import_link, skeleton, "99999999")
    end

    assert_equal(
      1, ExternalLink.where(target: skeleton, relationship: :import).count,
      "A duplicate import link attempt should be rejected, not added"
    )
  end

  def assert_naming_reason(obs)
    reason = obs.namings.first.reasons[2]
    today = Time.zone.today.strftime("%Y-%m-%d")
    assert_equal(
      "<a href=\"#{Inat::Constants::SITE}/observations/" \
      "#{FakeInatObs::FAKE_INAT_ID}\">iNat #{FakeInatObs::FAKE_INAT_ID}</a>, " \
      "#{:inat_leading_id.l} #{today}",
      reason,
      "Wrong 'Used references' reason text on the skeleton's naming"
    )
  end

  def assert_placeholder_notes(obs)
    notes = obs.notes_part_value(Observation.other_notes_part)
    inat_link = "\"iNat ##{FakeInatObs::FAKE_INAT_ID}\":" \
                "#{Inat::Constants::SITE}/observations/" \
                "#{FakeInatObs::FAKE_INAT_ID}"
    assert(
      notes.start_with?("Placeholder for #{inat_link},"),
      "Notes should be the placeholder text, linking to the iNat obs"
    )
    assert_includes(notes, "Daniel Morton",
                    "Placeholder notes should credit the iNat obs's owner")
  end

  # Unlike Inat::MoObservationBuilder (which wraps naming creation in
  # Naming.suppress_notifications so the import job can send one digest
  # per user instead), a skeleton naming fires its email notification
  # immediately (#4828) — Inat::ImportDigest excludes it from the
  # end-of-import digest to avoid double-notifying (see
  # inat_import_digest_test.rb).
  def test_mo_observation_does_not_suppress_notifications
    NameTracker.create!(name: names(:peltigera), user: users(:mary))

    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob) do
      builder_for(name: names(:peltigera)).mo_observation
    end
  end

  def test_naming_vote_research_grade_is_promising
    builder = builder_for(name: names(:peltigera), quality_grade: "research")
    assert_equal(Vote::NEXT_BEST_VOTE, builder.send(:naming_vote))
  end

  def test_naming_vote_non_research_is_could_be
    builder = builder_for(name: names(:peltigera), quality_grade: "needs_id")
    assert_equal(Vote::MIN_POS_VOTE, builder.send(:naming_vote))

    builder = builder_for(name: names(:peltigera), quality_grade: "casual")
    assert_equal(Vote::MIN_POS_VOTE, builder.send(:naming_vote))
  end

  def builder_for(name:, quality_grade: "needs_id")
    fake = FakeInatObs.new(name: name, quality_grade: quality_grade)
    Inat::SkeletonObservationBuilder.new(
      inat_obs: fake, user: users(:rolf),
      external_site: ExternalSite.inaturalist
    )
  end
end
