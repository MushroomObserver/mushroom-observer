# frozen_string_literal: true

# Phlex view for the species-list upload page. Page chrome plus the
# inline `Form` that posts the file under `species_list[file]`.
module Views::Controllers::SpeciesLists::Uploads
  class New < Views::FullPageBase
    prop :species_list, ::SpeciesList

    def view_template
      add_page_title(:species_list_upload_title.t)
      # Sibling reference within the module.
      render(Form.new(@species_list, local: false))
    end
  end
end
