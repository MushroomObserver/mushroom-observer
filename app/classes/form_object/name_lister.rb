# frozen_string_literal: true

# Form object for the name-lister submit form
# (`SpeciesLists::NameListsController#create`). The actual list of
# names is captured by the surrounding JavaScript UI and embedded as
# a single newline-separated string in `:results`.
class FormObject::NameLister < FormObject::Base
  attribute :results, :string
end
