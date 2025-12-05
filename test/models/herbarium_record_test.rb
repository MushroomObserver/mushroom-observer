# frozen_string_literal: true

require("test_helper")

class HerbariumRecordTest < UnitTestCase
  include ActiveJob::TestHelper

  def test_fields
    assert_not(herbarium_records(:interesting_unknown).observations.empty?)
    assert(herbarium_records(:interesting_unknown).herbarium)
    assert(herbarium_records(:interesting_unknown).herbarium_label)
    assert(herbarium_records(:interesting_unknown).notes)
  end

  def test_personal_herbarium_name_and_languages
    # Ensure the translations are initialized
    assert_equal("fungarium", :herbarium.t)
    TranslationString.store_localizations(
      :fr,
      { user_personal_herbarium: "[name]: Herbier Personnel" }
    )
    user = mary
    # disable cop in order to have proper scope for variable "herbarium"
    # rubocop:disable Rails/I18nLocaleAssignment
    I18n.locale = "en"
    assert_equal("Mary Newbie (mary): Personal Fungarium",
                 user.personal_herbarium_name)
    I18n.locale = "fr"
    assert_equal("Mary Newbie (mary): Herbier Personnel",
                 user.personal_herbarium_name)
    assert_objs_equal(nil, user.personal_herbarium)
    herbarium =
      Herbarium.create!(name: user.personal_herbarium_name, personal_user: user)
    assert_objs_equal(herbarium, user.personal_herbarium)
    I18n.locale = "en"
    # rubocop:enable Rails/I18nLocaleAssignment
    assert_objs_equal(herbarium, user.personal_herbarium)
    herbarium.update!(name: "My very own herbarium")
    assert_objs_equal(herbarium, user.personal_herbarium)
    assert_equal("My very own herbarium", user.personal_herbarium_name)
    I18n.with_locale(:fr) do
      assert_equal("My very own herbarium", user.personal_herbarium_name)
    end
  end

  # Test that creating a herbarium record by a non-curator emails the curators.
  def test_notify_curators_emails_curators
    nybg = herbaria(:nybg_herbarium)
    curators = nybg.curators
    assert(curators.count >= 2, "Need herbarium with multiple curators")
    non_curator = mary
    assert_not(curators.include?(non_curator))

    # Creating a record should enqueue emails to each curator
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      HerbariumRecord.create!(
        herbarium: nybg,
        user: non_curator,
        accession_number: "TEST-001",
        initial_det: "Agaricus campestris"
      )
    end
  end

  # Test that curators don't get emailed when they create their own records.
  def test_notify_curators_skips_self
    nybg = herbaria(:nybg_herbarium)
    curator = nybg.curators.first

    # Curator creating a record should NOT enqueue any emails
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      HerbariumRecord.create!(
        herbarium: nybg,
        user: curator,
        accession_number: "TEST-002",
        initial_det: "Agaricus campestris"
      )
    end
  end
end
