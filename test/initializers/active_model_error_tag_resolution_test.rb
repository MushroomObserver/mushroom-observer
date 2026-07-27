# frozen_string_literal: true

require("test_helper")

# config/initializers/active_model_error_tag_resolution.rb makes any
# Symbol raw_type -- Rails-native (:blank, :taken, ...) or MO's own --
# resolve through MO's mo.* i18n scope once a translation exists
# there, and fall through to Rails' own resolution otherwise.
class ActiveModelErrorTagResolutionTest < UnitTestCase
  def test_symbol_raw_type_resolves_through_mo_translation_once_defined
    TranslationString.store_localizations(
      :en, { active_model_error_tag_resolution_test_stub: "Stubbed text" }
    )

    user = users(:rolf)
    user.errors.add(:login,
                    :active_model_error_tag_resolution_test_stub)

    assert_equal("Stubbed text", user.errors.first.message)
  end

  def test_symbol_raw_type_without_mo_translation_falls_through_to_rails
    # :confirmation is a real Rails-native validation type this app
    # never gave an mo.* translation, so it must still resolve via
    # Rails' own bundled default instead of raising or going blank.
    assert_not(:confirmation.has_translation?)

    user = users(:rolf)
    user.errors.add(:login, :confirmation)

    assert_equal("doesn't match Login", user.errors.first.message)
  end
end
