# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Uploads
  # Form for uploading a species-list source file. Posts to
  # `SpeciesLists::UploadsController#create` under the
  # `species_list[file]` param namespace.
  class Form < ::Components::ApplicationForm
    def initialize(species_list, **attrs)
      super(species_list, multipart: true, **attrs)
    end

    def view_template
      super do
        file_field(:file, label: :species_list_upload_label)
        Help(content: :species_list_upload_help.tp)
        submit(:upload.ti, center: true)
      end
    end

    private

    def form_action
      url_for(controller: "/species_lists/uploads", action: :create,
              id: model.id, only_path: true)
    end
  end
end
