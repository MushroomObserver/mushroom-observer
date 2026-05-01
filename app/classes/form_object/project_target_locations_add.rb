# frozen_string_literal: true

# Form object backing the inline "Add target locations" textarea on
# the project Locations tab (#3991). One newline-separated string of
# location entries; the controller parses it into individual
# Location records.
class FormObject::ProjectTargetLocationsAdd < FormObject::Base
  attribute :locations, :string
end
