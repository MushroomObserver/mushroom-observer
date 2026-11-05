# frozen_string_literal: true

# Phlex view for the species-list downloads page. Renders three
# sibling forms — print-labels (`Form`), text-report (`ReportForm`),
# and the shared observations-download form
# (`Views::Controllers::Observations::Downloads::Form`).
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

      render_labels_section
      render_report_section
      render_observations_section
    end

    private

    def render_labels_section
      h3(class: "mt-5") { append_colon(:species_list_labels_header.l) }
      render(Form.new(query: @query))
    end

    def render_report_section
      h3 { append_colon(:species_list_report_header.t) }
      render(ReportForm.new(
               list: @list,
               query: @query,
               selected: @type
             ))
    end

    def render_observations_section
      h3(class: "mt-5") { :species_list_download_header.l }
      render(Views::Controllers::Observations::Downloads::Form.new(
               query: @query,
               format: @format,
               encoding: @encoding
             ))
    end
  end
end
