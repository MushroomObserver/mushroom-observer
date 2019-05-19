module PatternSearch
  class Observation < Base
    PARAMS = {
      date:            [:date,             :parse_date_range],
      created:         [:created_at,       :parse_date_range],
      modified:        [:updated_at,       :parse_date_range],

      name:            [:names,            :parse_list_of_names],
      synonym_of:      [:synonym_names,    :parse_list_of_names],
      child_of:        [:children_names,   :parse_list_of_names],

      herbarium:       [:herbaria,         :parse_list_of_herbaria],
      location:        [:locations,        :parse_list_of_locations],
      region:          [:region,           :parse_string],
      project:         [:projects,         :parse_list_of_projects],
      list:            [:species_lists,    :parse_list_of_species_lists],
      user:            [:users,            :parse_list_of_users],

      notes:           [:notes_has,        :parse_string],
      comments:        [:comments_has,     :parse_string],

      confidence:      [:confidence,       :parse_confidence],

      east:            [:east,             :parse_longitude],
      west:            [:west,             :parse_longitude],
      north:           [:north,            :parse_latitude],
      south:           [:south,            :parse_latitude],

      images:          [:has_images,       :parse_boolean],
      specimen:        [:has_specimen,     :parse_boolean],
      sequence:        [:has_sequences,    :parse_yes],
      lichen:          [:lichen,           :parse_boolean],
      has_name:        [:has_name,         :parse_boolean],
      has_notes:       [:has_notes,        :parse_boolean],
      has_field:       [:has_notes_fields, :parse_string],
      has_comments:    [:has_comments,     :parse_yes]
    }.freeze

    def self.params
      PARAMS
    end

    def params
      self.class.params
    end

    def self.model
      ::Observation
    end

    def model
      self.class.model
    end
  end
end
