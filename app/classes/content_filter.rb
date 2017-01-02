# encoding: utf-8
#
# This class describes a set of content-filtering parameters which can be
# applied to Query's.
#
# Class methods:
#
# all::                     Array of all available content filters.
# find(key)::               Look up a named filter.
# observation_filters::     Filters for observation queries.
# observation_filter_keys:: Keys for those observation filters.
# observation_filters_with_checkboxes:: Observation filters with checkboxes.
#
# Instance methods:
#
# sym::           Filter mame (symbol), same as Query param and User column.
# model::         Model on which filter operates.
# checkbox::      Name of account/prefs form checkbox (symbol).
# on_vals::       Array of allowed values when filter is on, in the order you
#                 want them to appear in advanced_filters
# checked_val::   Value when checkbox is checked.
# off_val::       Value when filter is off.
#
class ContentFilter

  # To add a new Content Filter: (The leading asterisk (*) indicates
  # an unnecessary step for new observation filter -- it's done
  # automatically.)
  #
  #   Add tests, e.g., to TestUserContentFilter
  #   Supplement fixtures as needed by added tests
  #   Add a filter definition below
  # * Add a new checkbox_val method in User
  #   In /config/locales/en.txt define text to be displayed before and next to
  #     check boxes, using prefs_obs_filters_has_images: as a model.
  # * Supplement _prefs_filters.html.erb as needed
  # * Add filter to AccountController#prefs_types & #update_content_filter
  #   For Observation filter, supplement Query::Initializers::ObservationFilters
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

  attr_accessor :sym
  attr_accessor :model
  attr_accessor :checkbox
  attr_accessor :on_vals
  attr_accessor :checked_val
  attr_accessor :off_val

  def initialize(opts)
    @sym          = opts[:sym]
    @model        = opts[:model]
    @checkbox     = opts[:checkbox]
    @on_vals      = opts[:on_vals]
    @checked_val  = opts[:checked_val]
    @off_val      = opts[:off_val]
  end

  # Array of all available filters.
  def self.all
    @@filters ||= [
      ContentFilter.new(
        sym:          :has_images,
        model:        Observation,
        checkbox:     :has_images_checkbox,
        on_vals:      ["yes", "no"],
        checked_val:  "yes",
        off_val:      nil
      ),
      ContentFilter.new(
        sym:          :has_specimen,
        model:        Observation,
        checkbox:     :has_specimen_checkbox,
        on_vals:      ["yes", "no"],
        checked_val:  "yes",
        off_val:      nil
      )
    ]
  end

  # Lookup a filter by name (symbol).
  def self.find(key)
    all.select { |fltr| fltr.sym == key }.first
  end

  # Array of filters which apply to obserations.
  def self.observation_filters
    all.select { |fltr| fltr.model == Observation }
  end

  # Array of observation filter names as symbols.
  def self.observation_filter_keys
    observation_filters.each_with_object([]) { |fltr, keys| keys << fltr.sym }
  end

  # Array of filters which use checkboxes.
  def self.observation_filters_with_checkboxes
    observation_filters.reject { |fltr| fltr.checkbox.nil? }
  end
end
