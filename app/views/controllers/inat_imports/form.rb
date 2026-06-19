# frozen_string_literal: true

module Views::Controllers::InatImports
  # Form for creating a new iNat import. Rendered by the inat_imports
  # controller's `new.rb` view. Renders username, observation IDs,
  # consent, and details.
  class Form < ::Components::ApplicationForm
    def initialize(model, super_importer: false, admin: false, **)
      @super_importer = super_importer
      @admin = admin
      super(model, **)
    end

    def view_template
      super do
        text_field(:inat_username,
                   label: "#{:inat_username.l}: ", size: 10)
        render_import_others_field if @super_importer
        render_skip_inat_update_field if @admin_mode
        render_choose_observations_panel
        checkbox_field(:consent,
                       label: :inat_import_consent.l,
                       wrap_class: "mt-3")
        render_skip_writeback_field if @admin
        render_details_panel
        submit(:SUBMIT.l)
      end
    end

    def form_action
      inat_imports_path
    end

    private

    def render_skip_inat_update_field
      checkbox_field(:skip_inat_update,
                     label: :inat_skip_inat_update.l,
                     wrap_class: "mt-3")
    end

    def render_import_others_field
      checkbox_field(:import_others,
                     label: :inat_import_others.l,
                     wrap_class: "mt-3")
    end

    def render_skip_writeback_field
      checkbox_field(:skip_inat_writeback,
                     label: :inat_skip_writeback.l,
                     wrap_class: "mt-3")
    end

    def render_choose_observations_panel
      render(Components::Panel.new(
               panel_id: "choose_observation",
               panel_class: "name-section"
             )) do |panel|
        panel.with_heading do
          plain(:inat_choose_observations.l)
        end
        panel.with_body do
          render_observation_fields
        end
      end
    end

    def render_observation_fields
      textarea_field(:inat_ids,
                     label: "#{:inat_import_list.l}: ")
      checkbox_field(:all,
                     label: :inat_import_all.l,
                     wrap_class: "mt-3")
      div(class: "mt-3") do
        text_field(:inat_url,
                   label: "#{:inat_url_label.l}: ")
        p(class: "help-block") { plain(:inat_url_hint.l) }
      end
    end

    def render_details_panel
      render(Components::Panel.new) do |panel|
        panel.with_body do
          p do
            b { plain(:inat_details_heading.l) }
          end
          trusted_html(:inat_details_list.t)
        end
      end
    end
  end
end
