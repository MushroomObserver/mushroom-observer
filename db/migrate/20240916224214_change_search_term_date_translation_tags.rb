class ChangeSearchTermDateTranslationTags < ActiveRecord::Migration[7.1]
  def up
    TranslationString.rename_tags(
      { search_term_date: :search_term_when,
        observation_term_date: :observation_term_when }
    )
  end
  def down
    TranslationString.rename_tags(
      { search_term_when: :search_term_date,
        observation_term_when: :observation_term_date }
    )
  end
end
