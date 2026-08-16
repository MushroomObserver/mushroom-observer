# frozen_string_literal: true

module Views::Controllers::Herbaria
  class Show
    # Add-curator form on `Herbaria::Show`, shown to curators/admins.
    # Posts to `Herbaria::CuratorsController#create`.
    class AddCuratorForm < ::Components::ApplicationForm
      prop :herbarium, ::Herbarium

      def initialize(herbarium:, **attrs)
        super(FormObject::HerbariumCurator.new,
              herbarium: herbarium, id: "herbarium_curators_form",
              local: false, **attrs)
      end

      def form_action
        herbaria_curators_path(id: @herbarium.id, q: q_param)
      end

      def view_template
        super do
          div(class: "form-inline mt-3") do
            autocompleter_field(:login, type: :user, label: false)
            label(for: "herbarium_curator_login") do
              Button(type: :submit, name: :show_herbarium_add_curator.t,
                     html_name: "commit")
            end
          end
        end
      end
    end
  end
end
