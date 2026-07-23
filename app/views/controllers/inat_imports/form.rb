# frozen_string_literal: true

module Views::Controllers::InatImports
  # Form for creating a new iNat import. Rendered by the inat_imports
  # controller's `new.rb` view. Renders username, observation method
  # radios (all / list of IDs / URL), consent, and details.
  class Form < ::Components::ApplicationForm
    def initialize(model, super_importer: false, admin: false, **)
      @super_importer = super_importer
      @admin = admin
      super(model, **)
    end

    def view_template
      super do
        render_inat_username_field
        render_import_others_field if @super_importer
        render_consent_checkbox
        render_choose_observations_section
        render_skip_writeback_field if @admin
        render_details_panel
        submit(:submit.ti)
      end
    end

    def form_action
      inat_imports_path
    end

    private

    def render_inat_username_field
      text_field(:inat_username,
                 label: :inat_username, size: 10, wrap_class: "mb-0")
    end

    def render_import_others_field
      checkbox_field(:import_others,
                     label: :inat_import_others,
                     wrap_class: "mt-1")
    end

    def render_skip_writeback_field
      checkbox_field(:skip_inat_writeback,
                     label: :inat_skip_writeback,
                     wrap_class: "mt-3")
    end

    def render_choose_observations_section
      Panel(panel_class: "my-5") do |panel|
        panel.with_heading { plain(:inat_what_to_import.l) }
        panel.with_body do
          div(data: { controller: "type-switch" }) do
            render_method_radio("all", :inat_import_all.l)
            render_method_radio("ids", :inat_import_list.l)
            render_ids_panel
            render_method_radio("url", :inat_url_label.l)
            render_url_panel
            render_recheck_all_field
          end
        end
      end
    end

    def render_method_radio(value, label_text)
      radio_field(:choose_method, [value, label_text],
                  wrap_class: "mt-0 mb-3",
                  data: { action: "change->type-switch#switch" })
    end

    def render_ids_panel
      Collapsible(expanded: current_method == "ids",
                  data: { type_switch_target: "panel",
                          type_switch_type: "ids" }) do
        textarea_field(:inat_ids, label: false,
                                  wrap_class: "ml-4",
                                  help: :inat_import_list_help.t)
      end
    end

    def render_url_panel
      Collapsible(expanded: current_method == "url",
                  data: { type_switch_target: "panel",
                          type_switch_type: "url" }) do
        textarea_field(:inat_url, label: false,
                                  wrap_class: "ml-4",
                                  rows: 4,
                                  help: :inat_url_hint.l,
                                  placeholder: "https://www.inaturalist.org" \
                                              "/observations?taxon_id=12345")
      end
    end

    def current_method
      model.choose_method.presence || "all"
    end

    # Applies to "all" and URL imports; id lists always re-check (#4565).
    def render_recheck_all_field
      checkbox_field(:recheck_all,
                     label: :inat_recheck_all,
                     help: :inat_recheck_all_help.l,
                     wrap_class: "mt-4")
    end

    def render_consent_checkbox
      checkbox_field(:consent,
                     label: :inat_import_consent,
                     wrap_class: "mt-3")
    end

    def render_details_panel
      Panel do |panel|
        panel.with_heading { plain(:inat_details_heading.l) }
        panel.with_body do
          ul(class: "pl-4") do
            detail_items.each { |key| li { plain(key.l) } }
          end
        end
      end
    end

    def detail_items
      [
        :inat_details_excludes,
        :inat_details_includes_all,
        :inat_details_fungi_only,
        :inat_details_data_fields,
        :inat_details_coordinates,
        :inat_details_location_name
      ]
    end
  end
end
