# filters which are applied in Query
module ContentFilter
# OLD INSTRUCTIONS (moved from User)
# To add a new Content Filter:
#   Add tests, e.g., to TestUserContentFilter
#   Supplement fixtures as needed by added tests
#   Supplement _prefs_filters.html.erb as needed
#   Add any methods required by a view checkbox to this section.
#   Add filter to AccountController#prefs_types & #update_content_filter
#   For Observation filter, supplement Query::Initializers::ObservationFilters
#   To filter another object, create a new initializer and include in
#     appropriate searches.
#   Supplement ApplicationController#show_index_of_objects as needed
#
# To be able to override the new filter in Advanced Searches, at least:
#   Add tests, e.g., to TestAdvancedSearchFilters
#   Supplement fixtures as needed by added tests
#   Supplement _advanced_search_filters.html.erb as needed
#   Supplement ObservationController#advanced_search_form as needed.
#   Supplement ApplicationController#show_index_of_objects as needed.
#   Supplement Query::RssLogBase as needed.
#
# To also add it as a Pattern Search
#   Supplement PatternSearchTest
#   Supplement classes/pattern_search/observation.rb or, if it's not and
#     Observation search add a new pattern_search file and class.
#
# There are probably other steps/files I've forgotten. JDC 2016-09-02
#
# New Instructions
#   Add tests, e.g., to TestUserContentFilter
#   Supplement fixtures as needed by added tests
#   define filter below

  ### filter definitions ###
  def has_images
    {
      name:         "has_images",         # filter name, as string
      sym:          :has_images,          # filter mame, as symbol
      model:        Observation,          # model on which filter operates
      checked_val:  "NOT NULL",           # value when checkbox checked
      off_val:      "off",                # filter is off
      on_vals:      ["NOT NULL", "NULL"], # allowed values when filter is on
      sql_cond:     "observations.thumb_image_id IS #{params[:has_images]}"
                                          # predicate added to Query where
    }
  end

  def has_specimen
    {
      name:         "has_specimen",
      sym:          :has_specimen,
      model:        Observation,
      checked_val:  "TRUE",
      off_val:      "off",
      on_vals:      ["TRUE", "FALSE"],
      sql_cond:     "observations.specimen IS #{params[:has_specimen]}"
   }
  end

  def filters
    [has_images, has_specimen]
  end

  ### other methods for use throughout application ###
  ### These reflect on above method definitions.
  def observation_filters
    filters.select { |fltr| fltr[:model] == Observation }
  end

  # array of observation_filter names as symbols
  def observation_filter_keys
    observation_filters.each_with_object([]) { |fltr, keys| keys << fltr[:sym] }
  end

  module_function(:has_images, :has_specimen, :filters, :observation_filters,
                  :observation_filter_keys)
end
