# frozen_string_literal: true

# helpers for search forms.
module SearchHelper
  def search_type_options
    [
      [:COMMENTS.l, :comments],
      [:GLOSSARY.l, :glossary_terms],
      [:HERBARIA.l, :herbaria],
      # Temporarily disabled for performance reasons. 2021-09-12 JDC
      # [:IMAGES.l, :images],
      [:LOCATIONS.l, :locations],
      [:NAMES.l, :names],
      [:OBSERVATIONS.l, :observations],
      [:PROJECTS.l, :projects],
      [:SPECIES_LISTS.l, :species_lists],
      [:HERBARIUM_RECORDS.l, :herbarium_records],
      [:USERS.l, :users],
      [:app_search_google.l, :google]
    ].sort
  end
end
