# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for the resync's image engine (#4215).
class Inat::ReflectionResyncImageSyncTest < UnitTestCase
  include ActiveJob::TestHelper

  FakeAPI2Response = Struct.new(:errors, :results)
  HOLDER = "(c) someone, some rights reserved (CC BY)"

  def setup
    @obs = observations(:imported_inat_obs)
    @obs.update_column(:reflected_at, Time.zone.now)
    @importer = @obs.user
    @site = ExternalSite.inaturalist
  end

  def test_matching_photos_are_a_noop
    image = add_image(1)
    @obs.update_column(:thumb_image_id, image.id)

    outcome = API2.stub(:execute, ->(_) { flunk("should not upload") }) do
      sync([photo(1)])
    end

    assert_not(outcome.changed?)
    assert_empty(outcome.alerts)
  end

  def test_photo_gone_from_inat_destroys_the_image
    kept = add_image(1)
    gone = add_image(2)
    @obs.update_column(:thumb_image_id, gone.id)

    outcome = sync([photo(1)])

    assert_equal(1, outcome.removed)
    assert_not(Image.exists?(gone.id))
    assert_equal(kept.id, @obs.reload.thumb_image_id,
                 "the thumbnail moves to the remaining iNat photo")
  end

  def test_gone_photo_used_elsewhere_is_detached_not_destroyed
    add_image(1)
    shared = add_image(2)
    other = observations(:minimal_unknown_obs)
    ObservationImage.create!(observation: other, image: shared)

    outcome = sync([photo(1)])

    assert(Image.exists?(shared.id))
    assert_not_includes(@obs.reload.images, shared)
    assert_includes(other.reload.images, shared)
    assert_match(/used elsewhere/, outcome.alerts.first)
  end

  # An importer with no inat_username (a super importer) counts as
  # someone else.
  def test_photo_unlicensed_on_someone_elses_observation_is_removed
    @importer.update_column(:inat_username, nil)
    add_image(1)
    lost = add_image(2)

    outcome = sync([photo(1), photo(2, license: nil)])

    assert_equal(1, outcome.removed)
    assert_not(Image.exists?(lost.id))
  end

  # The importer agreed to license their photo this way at import, so a
  # later change to their default license doesn't relicense the image.
  def test_photo_unlicensed_on_the_importers_observation_keeps_its_license
    @importer.update_column(:inat_username, "dick_on_inat")
    image = add_image(1, license: licenses(:ccbync))
    @importer.update_column(:license_id, licenses(:ccby).id)

    outcome = sync([photo(1, license: nil)], login: "Dick_On_iNat")

    assert_equal(0, outcome.removed)
    assert_equal(licenses(:ccbync).id, image.reload.license_id)
  end

  def test_license_and_copyright_holder_follow_inat
    image = add_image(1, license: licenses(:ccbync),
                         holder: "(c) old_login, some rights reserved")

    outcome = sync([photo(1, license: "cc-by")])

    image.reload
    assert_equal(1, outcome.updated)
    assert(outcome.logs_resync?)
    assert_equal(licenses(:ccby).id, image.license_id)
    assert_equal(HOLDER, image.copyright_holder)
    change = CopyrightChange.where(target: image).order(:id).last
    assert_equal(User.admin, change.user, "recorded as the resync")
  end

  def test_new_photo_is_imported_and_transferred
    add_image(1)
    created = Image.create!(user: @importer, license: licenses(:ccby),
                            copyright_holder: HOLDER)

    outcome = nil
    assert_enqueued_with(job: TransferImagesJob,
                         args: [{ image_ids: [created.id] }]) do
      API2.stub(:execute, lambda { |_|
        ObservationImage.create!(observation: @obs, image: created)
        FakeAPI2Response.new([], [created])
      }) do
        outcome = sync([photo(1), photo(3)])
      end
    end

    assert_equal(1, outcome.added)
    assert_not_nil(ExternalLink.find_by(target: created, external_id: "3"))
  end

  def test_failed_import_is_reported
    add_image(1)
    error = API2::MissingParameter.new(:upload_url)

    outcome = API2.stub(:execute, lambda { |_|
      FakeAPI2Response.new([error], nil)
    }) do
      sync([photo(1), photo(3)])
    end

    assert_equal(0, outcome.added)
    assert_match(/iNat photo 3 not imported/, outcome.alerts.first)
  end

  def test_thumbnail_follows_the_first_photo_with_sharing_members
    first = add_image(1)
    second = add_image(2)
    @obs.update_column(:thumb_image_id, first.id)
    sharing, other = occurrence_members
    sharing.update_column(:thumb_image_id, first.id)
    other.update_column(:thumb_image_id, images(:in_situ_image).id)

    outcome = sync([photo(2), photo(1)])

    assert(outcome.thumbnail_changed)
    assert_equal(second.id, @obs.reload.thumb_image_id)
    assert_equal(second.id, sharing.reload.thumb_image_id,
                 "a member sharing the old thumbnail moves with it")
    assert_equal(images(:in_situ_image).id, other.reload.thumb_image_id)
  end

  def test_thumbnail_on_a_non_inat_image_is_left_alone
    add_image(1)
    native = unlinked_image(dhash: 0)
    @obs.update_column(:thumb_image_id, native.id)

    outcome = sync([photo(1)], dhash: 0xFFFF_FFFF_FFFF_FFFF)

    assert_not(outcome.thumbnail_changed)
    assert_equal(native.id, @obs.reload.thumb_image_id)
  end

  # An image with no photo link that matches one of the observation's
  # iNat photos is an iNat image, so it follows iNat.
  def test_unlinked_thumbnail_matching_an_inat_photo_follows_inat
    linked = add_image(1)
    unlinked = unlinked_image(dhash: 0b1111)
    @obs.update_column(:thumb_image_id, unlinked.id)

    outcome = sync([photo(1)], dhash: 0b0111)

    assert(outcome.thumbnail_changed)
    assert_equal(linked.id, @obs.reload.thumb_image_id)
  end

  def test_thumbnail_left_alone_when_hashing_fails
    add_image(1)
    unlinked = unlinked_image(dhash: 0)
    @obs.update_column(:thumb_image_id, unlinked.id)

    outcome = sync([photo(1)], dhash: ->(_) { raise("S3 down") })

    assert_equal(unlinked.id, @obs.reload.thumb_image_id)
    assert_match(/not hashed: S3 down/, outcome.alerts.first)
  end

  def test_thumbnail_not_attached_to_the_reflection_is_left_alone
    add_image(1)
    @obs.update_column(:thumb_image_id, images(:in_situ_image).id)

    outcome = sync([photo(1)])

    assert_not(outcome.thumbnail_changed)
    assert_equal(images(:in_situ_image).id, @obs.reload.thumb_image_id)
  end

  private

  def sync(photos, login: "someone_on_inat", dhash: 0)
    hasher = dhash.respond_to?(:call) ? dhash : ->(_) { dhash }
    inat_obs = Inat::Obs.new(JSON.generate(
                               { id: 12_345, user: { login: login },
                                 observation_photos: photos }
                             ))
    Inat::ReflectionResync::ImageSync.new(dhash_for: hasher).
      call(@obs.reload, inat_obs)
  end

  # An iNat observation_photo entry.
  def photo(id, license: "cc-by", position: nil)
    { photo_id: id, position: position,
      photo: { id: id, license_code: license, attribution: HOLDER,
               url: "https://inaturalist-open-data.s3.amazonaws.com/" \
                    "photos/#{id}/square.jpeg" } }
  end

  # An imported image on the reflection, linked to an iNat photo id.
  def add_image(photo_id, license: licenses(:ccby), holder: HOLDER)
    image = Image.create!(user: @importer, license: license,
                          copyright_holder: holder)
    ObservationImage.create!(observation: @obs, image: image)
    ExternalLink.create!(user: @importer, target: image, external_site: @site,
                         external_id: photo_id.to_s, relationship: :import)
    image
  end

  def unlinked_image(dhash:)
    image = Image.create!(user: @importer, license: licenses(:ccby),
                          copyright_holder: HOLDER)
    image.update_column(:dhash, dhash)
    ObservationImage.create!(observation: @obs, image: image)
    image
  end

  # Two other members of an occurrence with the reflection.
  def occurrence_members
    sharing = observations(:minimal_unknown_obs)
    other = observations(:detailed_unknown_obs)
    [sharing, other, @obs].each { |o| o.update_column(:occurrence_id, nil) }
    occ = Occurrence.create!(user: sharing.user, primary_observation: sharing)
    [sharing, other, @obs].each { |o| o.update_column(:occurrence_id, occ.id) }
    [sharing, other]
  end
end
