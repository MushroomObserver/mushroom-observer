# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Downloads
  # Form for downloading a species-list report in a chosen text
  # format. Posts to `SpeciesLists::DownloadsController#create`.
  # Sibling to `Views::Controllers::SpeciesLists::Downloads::Form`
  # (the print-labels form, also on the downloads/new page).
  class ReportForm < ::Components::ApplicationForm
    def initialize(list:, query_param:, selected: nil)
      @list = list
      @query_param = query_param
      super(FormObject::SpeciesListReport.new(format: selected),
            id: "species_list_download_report")
    end

    def view_template
      super do
        h3 { "#{:species_list_report_header.t}:" }
        p { "#{:download_observations_format.t}:" }
        div(class: "form-group") { render_format_radios }
        submit(:species_list_report_button.l, center: true)
      end
    end

    private

    def render_format_radios
      radio_field(
        :format,
        [:txt, :species_list_show_save_as_txt.t],
        [:rtf, :species_list_show_save_as_rtf.t],
        [:csv, :species_list_show_save_as_csv.t]
      )
    end

    def form_action
      url_for(controller: "/species_lists/downloads",
              action: :create, id: @list.id, q: @query_param,
              only_path: true)
    end
  end
end
