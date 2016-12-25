# encoding: utf-8

module PatternSearch
  class Observation < Base
    def build_query
      self.model  = :Observation
      self.flavor = :all
      self.args   = {}
      for term in parser.terms
        if term.var == :pattern
          self.flavor = :pattern_search
          args[:pattern] = term.parse_pattern

        elsif term.var == :date
          args[:date] = term.parse_date_range
        elsif term.var == :created
          args[:created_at] = term.parse_date_range
        elsif term.var == :modified
          args[:updated_at] = term.parse_date_range

        elsif term.var == :name
          args[:names] = term.parse_list_of_names
        elsif term.var == :synonym_of
          args[:synonym_names] = term.parse_list_of_names
        elsif term.var == :child_of
          args[:children_names] = term.parse_list_of_names

        elsif term.var == :location
          args[:locations] = term.parse_list_of_locations
        elsif term.var == :project
          args[:projects] = term.parse_list_of_projects
        elsif term.var == :list
          args[:species_lists] = term.parse_list_of_species_lists
        elsif term.var == :user
          args[:users] = term.parse_list_of_users

        elsif term.var == :notes
          args[:notes_has] = term.parse_string
        elsif term.var == :comments
          args[:comments_has] = term.parse_string

        elsif term.var == :confidence
          args[:confidence] = term.parse_confidence

        elsif term.var == :east
          args[:east] = term.parse_float(-180, 180)
        elsif term.var == :west
          args[:west] = term.parse_float(-180, 180)
        elsif term.var == :north
          args[:north] = term.parse_float(-90, 90)
        elsif term.var == :south
          args[:south] = term.parse_float(-90, 90)

        elsif term.var == :images
          args[:has_images] = term.parse_to_null_not_null_string
        elsif term.var == :specimen
          args[:has_specimen] = term.parse_to_true_false_string
        elsif term.var == :has_name
          args[:has_name] = term.parse_boolean
        elsif term.var == :has_notes
          args[:has_notes] = term.parse_boolean
        elsif term.var == :has_comments
          args[:has_comments] = term.parse_boolean(:only_yes) && "yes"

        else
          fail BadObservationTermError.new(term: term)
        end
      end
    end
  end
end
