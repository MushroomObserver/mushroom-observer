# frozen_string_literal: true

# Lowercase five theme-name tags -- real, hand-translated
# `translation_strings` rows (Agaricus/Amanita/BlackOnWhite/
# Cantharellaceae/Hygrocybe have content in 5-6 languages, including
# a genuinely per-language-translated `BlackOnWhite`, not just a
# repeated Latin genus name) that were missed by the #4843 ALL-CAPS/
# lowercase twin-tag sweep because they were never in
# config/locales/en.txt at all -- only in the DB.
# `TranslationString.rename_tags` preserves the existing content
# across every language; nothing here is newly translated.
class LowercaseThemeTranslationTags < ActiveRecord::Migration[7.2]
  RENAMES = {
    Agaricus: :agaricus,
    Amanita: :amanita,
    BlackOnWhite: :black_on_white,
    Cantharellaceae: :cantharellaceae,
    Hygrocybe: :hygrocybe
  }.freeze

  def up
    TranslationString.rename_tags(RENAMES)
  end

  def down
    TranslationString.rename_tags(RENAMES.invert)
  end
end
