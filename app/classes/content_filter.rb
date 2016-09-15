# filters which are applied in Query
module ContentFilter

# To add a new Content Filter:
# * Indicates unnecessary for new observation filter -- it's done automatically.
#
#   Add tests, e.g., to TestUserContentFilter
#   Supplement fixtures as needed by added tests
#   Add a filter definition below, and add that definition to #filters below
#   Add a new checkbox_val method in User
#   In /config/locales/en.txt define text to be displayed before and next to
#     check boxes, using prefs_obs_filters_has_images: as a model.
# * Supplement _prefs_filters.html.erb as needed
# * Add filter to AccountController#prefs_types & #update_content_filter
# * For Observation filter, supplement Query::Initializers::ObservationFilters
# * Supplement ApplicationController#show_index_of_objects as needed
#   To filter another object, create a new initializer and include in
#     appropriate searches.
#
# To be able to override the new filter in Advanced Searches, at least:
#   Add tests, e.g., to TestAdvancedSearchFilters
#   Supplement fixtures as needed by added tests
#   In /config/locales/en.txt define text to be displayed before and next to
#     radio boxes, using advanced_search_filter_has_images: as a model.
# * Supplement _advanced_search_filters.html.erb as needed
# * Supplement ObservationController#advanced_search_form as needed.
# * Supplement ApplicationController#show_index_of_objects as needed.
# * Supplement Query::RssLogBase as needed.
#
# To also add it as a Pattern Search
#   Supplement PatternSearchTest
#   Supplement classes/pattern_search/observation.rb or -- if it's not an
#     Observation search -- add a new pattern_search file and class.
#
# There are probably other steps/files I've forgotten. JDC 2016-09-15

  ### filter definitions ###
  # In the order you want filters to appear in advanced_search
  # name:         filter name, as string
  # sym:          filter mame, as symbol
  # model:        model on which filter operates.  Used by ContentFilter
  # checkbox:     prefs form checkbox, e.g., :has_images_checkbox.
  #               Used by prefs view
  # checked_val:  value when checkbox checked
  # off_val:      value when filter is off
  # on_vals:      array of allowed values when filter is on,
  #               in order you want them to appear in advanced_filters
  # sql_cond:     predicate added to Query "where", when filter is on.  E.g.:
  #               "observations.specimen IS #{params[:has_specimen]}"

  def has_images
    {
      name:         "has_images",
      sym:          :has_images,
      model:        Observation,
      checkbox:     :has_images_checkbox,
      checked_val:  "NOT NULL",
      off_val:      "off",
      on_vals:      ["NOT NULL", "NULL"],
      sql_cond:     "observations.thumb_image_id IS #{params[:has_images]}"
    }
  end

  def has_specimen
    {
      name:         "has_specimen",
      sym:          :has_specimen,
      model:        Observation,
      checkbox:     :has_specimen_checkbox,
      checked_val:  "TRUE",
      off_val:      "off",
      on_vals:      ["TRUE", "FALSE"],
      sql_cond:     "observations.specimen IS #{params[:has_specimen]}"
   }
  end

  def filters
    [has_images, has_specimen]
  end

  ### These reflect on above methods.
  def observation_filters
    filters.select { |fltr| fltr[:model] == Observation }
  end

  # array of observation_filter names as symbols
  def observation_filter_keys
    observation_filters.each_with_object([]) { |fltr, keys| keys << fltr[:sym] }
  end

  # Lets view check whether to create checkbox.
  def observation_filters_with_checkboxes
    observation_filters.select { |fltr| fltr[:checkbox].present? }
  end

  module_function(:has_images, :has_specimen, :filters, :observation_filters,
                  :observation_filter_keys)
end
