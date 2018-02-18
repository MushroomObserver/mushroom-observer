module PatternSearch
  class Name < Base
    PARAMS = {
      created:            [:created_at,         :parse_date_range],
      modified:           [:updated_at,         :parse_date_range],

      rank:               [:rank,               :parse_rank_range],
      synonym_of:         [:synonym_names,      :parse_list_of_names],
      child_of:           [:children_names,     :parse_list_of_names],
      has_synonyms:       [:has_synonyms,       :parse_boolean],
      deprecated:         [:is_deprecated,      :parse_boolean],
      misspelled:         [:misspellings,       :parse_yes_no_both],
      lichen:             [:lichen,             :parse_boolean],

      has_author:         [:has_author,         :parse_boolean],
      has_citation:       [:has_citation,       :parse_boolean],
      has_classification: [:has_classification, :parse_boolean],
      has_notes:          [:has_notes,          :parse_boolean],
      has_comments:       [:has_comments,       :parse_yes],
      has_description:    [:has_default_desc,   :parse_boolean],
      has_observations:   [:has_observations,   :parse_yes],

      author:             [:author_has,         :parse_string],
      citation:           [:citation_has,       :parse_string],
      classification:     [:classification_has, :parse_string],
      notes:              [:notes_has,          :parse_string],
      comments:           [:comments_has,       :parse_string]
    }.freeze

    def params
      PARAMS
    end

    def model
      ::Name
    end
  end
end
