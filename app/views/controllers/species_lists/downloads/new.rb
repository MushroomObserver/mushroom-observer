# frozen_string_literal: true

# Phlex view for the species-list downloads page. Renders two sibling
# forms — the checklist-save form (`SaveChecklistForm`) and the shared
# observations-download form
# (`Views::Controllers::Observations::Downloads::Form`, whose own
# "Print Labels" button already covers printing labels for this
# list's observations, so there's no separate labels form here).
module Views::Controllers::SpeciesLists::Downloads
  class New < Views::FullPageBase
    prop :list, ::SpeciesList
    prop :query, ::Query
    prop :type, String
    prop :format, String
    prop :encoding, String

    def view_template
      add_page_title(:species_list_download_title.t)
      add_context_nav(Tab::Object::Return.new(object: @list))

      hr
      render_checklist_section
      hr
      render_observations_section
    end

    private

    def render_checklist_section
      h4 { :species_list_report_header.l }
      render(SaveChecklistForm.new(
               list: @list,
               query: @query,
               selected: @type
             ))
    end

    def render_observations_section
      h4 { :species_list_download_header.l }
      render(Views::Controllers::Observations::Downloads::Form.new(
               query: @query,
               format: @format,
               encoding: @encoding
             ))
    end
  end
end
