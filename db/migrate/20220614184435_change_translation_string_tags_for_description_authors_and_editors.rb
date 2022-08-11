class ChangeTranslationStringTagsForDescriptionAuthorsAndEditors < ActiveRecord::Migration[6.1]
  TAG_PAIRS =     [
    %w[
      user_stats_location_descriptions_authors
      user_stats_location_description_authors
    ],
    %w[
      user_stats_location_descriptions_editors
      user_stats_location_description_editors
    ],
    %w[
      user_stats_name_descriptions_authors
      user_stats_name_description_authors
    ],
    %w[
      user_stats_name_descriptions_editors
      user_stats_name_description_editors
    ],
    %w[
      site_stats_location_descriptions_authors
      site_stats_location_description_authors
    ],
    %w[
      site_stats_location_descriptions_editors
      site_stats_location_description_editors
    ],
    %w[
      site_stats_name_descriptions_authors
      site_stats_name_description_authors
    ],
    %w[
      site_stats_name_descriptions_editors
      site_stats_name_description_editors
    ]
  ]

  def change
    TAG_PAIRS.each do |from, to|
      TranslationString.where(tag: from).update_all(tag: to)
    end
  end
end
