class FilterTranslationStringsWithToHas < ActiveRecord::Migration[7.2]
  def up
    TranslationString.rename_tags({
      prefs_filters_with_images: :prefs_filters_has_images,
      prefs_filters_with_specimen: :prefs_filters_has_specimen,
      advanced_search_filter_with_images:
      advanced_search_filter_has_images,
      advanced_search_filter_with_images_off:
      advanced_search_filter_has_images_off,
      advanced_search_filter_with_images_yes:
      advanced_search_filter_has_images_yes,
      advanced_search_filter_with_images_no:
      advanced_search_filter_has_images_no,
      advanced_search_filter_with_specimen:
      advanced_search_filter_has_specimen,
      advanced_search_filter_with_specimen_off:
      advanced_search_filter_has_specimen_off,
      advanced_search_filter_with_specimen_yes:
      advanced_search_filter_has_specimen_yes,
      advanced_search_filter_with_specimen_no:
      advanced_search_filter_has_specimen_no
    })
  end
  def down
    TranslationString.rename_tags({
      prefs_filters_has_images: :prefs_filters_with_images,
      prefs_filters_has_specimen: :prefs_filters_with_specimen,
      advanced_search_filter_has_images:
      advanced_search_filter_with_images,
      advanced_search_filter_has_images_off:
      advanced_search_filter_with_images_off,
      advanced_search_filter_has_images_yes:
      advanced_search_filter_with_images_yes,
      advanced_search_filter_has_images_no:
      advanced_search_filter_with_images_no,
      advanced_search_filter_has_specimen:
      advanced_search_filter_with_specimen,
      advanced_search_filter_has_specimen_off:
      advanced_search_filter_with_specimen_off,
      advanced_search_filter_has_specimen_yes:
      advanced_search_filter_with_specimen_yes,
      advanced_search_filter_has_specimen_no:
      advanced_search_filter_with_specimen_no
    })
  end
end
