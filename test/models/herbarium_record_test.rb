# frozen_string_literal: true

require "test_helper"

class HerbariumRecordTest < UnitTestCase
  def test_fields
    assert_not(herbarium_records(:interesting_unknown).observations.empty?)
    assert(herbarium_records(:interesting_unknown).herbarium)
    assert(herbarium_records(:interesting_unknown).herbarium_label)
    assert(herbarium_records(:interesting_unknown).notes)
  end

  def test_personal_herbarium_name_and_languages
    # Ensure the translations are initialized
    assert_equal("herbarium", :herbarium.t)
    TranslationString.translations(:fr)[:user_personal_herbarium] =
      "[name]: Herbier Personnel"
    user = mary
    I18n.locale = "en"
    assert_equal("Mary Newbie (mary): Personal Herbarium",
                 user.personal_herbarium_name)
    I18n.locale = "fr"
    assert_equal("Mary Newbie (mary): Herbier Personnel",
                 user.personal_herbarium_name)
    assert_objs_equal(nil, user.personal_herbarium)
    herbarium =
      Herbarium.create!(name: user.personal_herbarium_name, personal_user: user)
    assert_objs_equal(herbarium, user.personal_herbarium)
    I18n.locale = "en"
    assert_objs_equal(herbarium, user.personal_herbarium)
    herbarium.update!(name: "My very own herbarium")
    assert_objs_equal(herbarium, user.personal_herbarium)
    assert_equal("My very own herbarium", user.personal_herbarium_name)
    I18n.locale = "fr"
    assert_equal("My very own herbarium", user.personal_herbarium_name)
  end
end
