# frozen_string_literal: true

# Lowercase five theme-name tags (Agaricus/Amanita/BlackOnWhite/
# Cantharellaceae/Hygrocybe), each with translated content in 5-6
# languages. `TranslationString.rename_tags` preserves the existing
# content across every language; nothing here is newly translated.
#
# Run this before `rails lang:update`, not after -- `lang:update`
# deletes any `translation_strings` row whose tag isn't in
# `config/locales/en.txt`.
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
