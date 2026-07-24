# frozen_string_literal: true

# Collection-numbers section of the Specimen panel on the observation
# show page. All rendering shape lives on RecordListSection -- this
# class only supplies the model identity.
class Views::Controllers::Observations::Show::SpecimenPanel
  class CollectionNumbersSection < RecordListSection
    self.model_class = ::CollectionNumber
  end
end
