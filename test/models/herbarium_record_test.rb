# frozen_string_literal: true

require("test_helper")

class HerbariumRecordTest < UnitTestCase
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

  def test_accession_number_uniqueness_within_herbarium
    nybg = herbaria(:nybg_herbarium)
    rolf_herbarium = herbaria(:rolf_herbarium)
    user = users(:rolf)

    # Creating a record with a new accession number should succeed
    record1 = HerbariumRecord.create!(
      herbarium: nybg,
      user: user,
      initial_det: "Test species 1",
      accession_number: "TEST-001"
    )
    assert(record1.persisted?)

    # Creating another record with the same accession number in the same herbarium should fail
    record2 = HerbariumRecord.new(
      herbarium: nybg,
      user: user,
      initial_det: "Test species 2",
      accession_number: "TEST-001"
    )
    assert_not(record2.valid?)
    assert(record2.errors[:accession_number].present?)

    # Creating a record with the same accession number in a different herbarium should succeed
    record3 = HerbariumRecord.create!(
      herbarium: rolf_herbarium,
      user: user,
      initial_det: "Test species 3",
      accession_number: "TEST-001"
    )
    assert(record3.persisted?)
  end
end
