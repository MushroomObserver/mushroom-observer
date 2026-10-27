# frozen_string_literal: true

require("test_helper")

# Deleting an MO user's images (#5521). Besides mary's fixture images,
# she uploaded one more image to MO and has one iNat photo that dick
# imported.
class ImagePurgeJobTest < ActiveJob::TestCase
  INAT_NAME = "Mary Newbie"

  def setup
    super
    @mary = users(:mary)
    @mary.update!(inat_username: "mary_on_inat")
    @site = ExternalSite.inaturalist
    build_world
  end

  def test_plan
    plan = ImagePurge::Plan.new(target_user: @mary)

    with_inat_name do
      images = plan.images.to_a
      assert_includes(images, @native_image)
      assert_includes(images, @inat_image)
      assert_not_includes(images, @kept_image,
                          "Someone else's photo mary imported is not hers")
      assert_includes(plan.native_observations, @native_obs)
      assert_not_includes(plan.native_observations, @others_obs)
      assert_equal([@reflection], plan.placeholder_observations.to_a)
    end
  end

  def test_purge
    purge = ImagePurge.create!(user: @mary, target_user: @mary)
    expected = with_inat_name { expected_counts }

    with_inat_name do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
        ImagePurgeJob.perform_now(purge)
      end
    end

    assert_purge_counts(purge.reload, expected)
    assert_records_after_purge
    assert_notices
  end

  # A run cut short is finished by running again; nobody is emailed twice.
  def test_rerun_finishes_without_emailing_again
    purge = ImagePurge.create!(user: @mary, target_user: @mary,
                               notified_at: Time.zone.now)
    expected = with_inat_name { expected_counts }

    with_inat_name { ImagePurgeJob.perform_now(purge) }
    with_inat_name { ImagePurgeJob.perform_now(purge) }

    mailers = enqueued_jobs.map { |job| job[:args].first }
    assert_not_includes(mailers, "ImagePurgeMailer",
                        "The purge emails went out with the first run")
    assert_not(Image.exists?(@inat_image.id))
    assert_equal(expected[:images], purge.reload.deleted_image_count)
  end

  # An excluded iNat user has no MO account: only their imported photos.
  def test_purge_for_an_excluded_inat_login
    purge = ImagePurge.create!(user: users(:rolf), inat_login: "mary_on_inat")

    with_inat_name { ImagePurgeJob.perform_now(purge) }

    assert(purge.reload.done?)
    assert_equal(1, purge.deleted_image_count)
    assert_not(Image.exists?(@inat_image.id))
    assert(Image.exists?(@native_image.id),
           "An image uploaded to MO is not an iNat photo")
  end

  def test_failure_is_recorded
    purge = ImagePurge.create!(user: @mary, target_user: @mary)

    ImagePurge::Plan.stub(:new, ->(**) { raise("boom") }) do
      ImagePurgeJob.perform_now(purge)
    end

    assert(purge.reload.failed?)
    assert_equal("boom", purge.error)
  end

  private

  def build_world
    @native_obs = observations(:minimal_unknown_obs) # mary's, not imported
    @native_obs.update_columns(notes: { Other: "Under an oak" })
    # mary's, showing none of the deleted images
    @imageless_obs = Observation.where(user: @mary).
                     where.missing(:observation_images).first
    @imageless_obs.update_columns(notes: { Other: "Smelled of anise" })
    @others_obs = observations(:coprinus_comatus_obs) # rolf's
    @reflection = observations(:imported_inat_obs) # dick's import
    @native_image = image(@mary, @mary.legal_name, [@native_obs, @others_obs])
    GlossaryTermImage.create!(
      glossary_term: glossary_terms(:conic_glossary_term), image: @native_image
    )
    @inat_image = image(users(:dick), "(c) #{INAT_NAME}, some rights " \
                                      "reserved (CC BY)", [@reflection])
    ProjectImage.create!(project: projects(:bolete_project), image: @inat_image)
    import_link(@inat_image, "900")
    @kept_image = image(@mary, "(c) someone else, some rights reserved " \
                               "(CC BY)", [])
    import_link(@kept_image, "901")
  end

  def image(user, holder, observations)
    image = Image.create!(user: user, license: licenses(:ccby),
                          copyright_holder: holder)
    observations.each do |obs|
      ObservationImage.create!(observation: obs, image: image)
    end
    image
  end

  def import_link(image, photo_id)
    ExternalLink.create!(user: image.user, target: image, external_site: @site,
                         external_id: photo_id, relationship: :import)
  end

  def with_inat_name(&block)
    Inat::UserLookup.stub(:call, { "name" => INAT_NAME }, &block)
  end

  def expected_counts
    plan = ImagePurge::Plan.new(target_user: @mary)
    { images: plan.image_count,
      notes_cleared: plan.native_observations.count { |o| o.notes.present? } }
  end

  def assert_purge_counts(purge, expected)
    assert(purge.done?, "Purge failed: #{purge.error}")
    assert_equal(expected[:images], purge.image_count)
    assert_equal(expected[:images], purge.deleted_image_count)
    assert_equal(expected[:notes_cleared], purge.cleared_notes_count)
    assert_equal(1, purge.placeholder_count)
    assert_not_nil(purge.notified_at)
  end

  def assert_records_after_purge
    @native_obs.reload
    assert_empty(@native_obs.images, "mary's observation loses the images")
    assert_equal(Observation.no_notes, @native_obs.notes,
                 "mary's observation uploaded to MO loses its notes")
    assert_not(@native_obs.placeholder?,
               "An observation uploaded to MO is not a placeholder")
    assert_equal(Observation.no_notes, @imageless_obs.reload.notes,
                 "All of mary's observations uploaded to MO lose their notes")
    assert(Observation.exists?(@others_obs.id), "rolf's observation stays")
    assert_not_includes(@others_obs.reload.images.map(&:id), @native_image.id)
    @reflection.reload
    assert(@reflection.placeholder?,
           "An imported observation left with no images is a placeholder")
    assert_equal(Observation.no_notes, @reflection.notes)
    assert(Image.exists?(@kept_image.id),
           "Someone else's photo that mary imported stays")
  end

  def assert_notices
    mails = ActionMailer::Base.deliveries
    receivers = mails.map { |m| User.find_by(email: m.to.first).login }
    assert_includes(receivers, "dick")
    assert_includes(receivers, "rolf")
    assert_not_includes(receivers, "mary", "mary is not emailed")
    assert_includes(mail_text(mails, :dick), @reflection.import_link.link_url,
                    "An iNat photo links to its iNat observation")
    assert_includes(mail_text(mails, :dick), projects(:bolete_project).title)
    assert_includes(mail_text(mails, :rolf), :image_purge_email_no_source.l,
                    "A photo uploaded to MO has nothing to link to")
  end

  def mail_text(mails, login)
    mail = mails.find { |m| m.to.first == users(login).email }
    (mail.text_part || mail).body.decoded
  end
end
