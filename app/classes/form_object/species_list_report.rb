# frozen_string_literal: true

# Form object for the species-list report-download form.
# Wraps the report format choice (`txt` / `rtf` / `csv`) posted by
# `Views::Controllers::SpeciesLists::Downloads::ReportForm` to
# `SpeciesLists::DownloadsController#create`.
class FormObject::SpeciesListReport < FormObject::Base
  attribute :format, :string, default: "txt"
end
