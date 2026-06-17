# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Uploads
  # Form for uploading a species-list source file. Posts to
  # `SpeciesLists::UploadsController#create` under the
  # `species_list[file]` param namespace.
  class Form < ::Components::ApplicationForm
    def initialize(species_list, **)
      @species_list = species_list
      super(species_list, multipart: true)
    end

    def view_template
      super do
        file_field(:file, label: "#{:species_list_upload_label.t}:")
        render(Components::Help::Block.new(:div, :species_list_upload_help.tp))
        submit(:UPLOAD.l, center: true)
      end
    end

    private

    def form_action
      url_for(controller: "/species_lists/uploads", action: :create,
              id: @species_list.id, only_path: true)
    end
  end
end
