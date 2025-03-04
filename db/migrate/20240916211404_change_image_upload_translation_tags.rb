class ChangeImageUploadTranslationTags < ActiveRecord::Migration[7.1]
  def up
    TranslationString.rename_tags(
      { profile_copyright_holder: :image_copyright_holder,
        profile_copyright_warning: :image_copyright_warning }
    )
  end
  def down
    TranslationString.rename_tags(
      { image_copyright_holder: :profile_copyright_holder,
        image_copyright_warning: :profile_copyright_warning }
    )
  end
end
