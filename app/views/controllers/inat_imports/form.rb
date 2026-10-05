# frozen_string_literal: true

module Views::Controllers::InatImports
  # Form for creating a new iNat import. Rendered by the inat_imports
  # controller's `new.rb` view. Renders username, observation method
  # radios (all / list of IDs / URL), consent, and details.
  class Form < ::Components::ApplicationForm
    prop :super_importer, _Boolean, default: false
    prop :admin, _Boolean, default: false
    # Set when a project admin started this from their project's Admin
    # tab (#5416). What such an import covers is the project's
    # configuration, so the scope is shown rather than chosen.
    prop :project_site, _Nilable(::ProjectExternalSite), default: nil

    def view_template
      super do
        render_inat_username_field
        if may_import_others?
          render_import_others_field
          render_create_skeletons_field
        end
        render_consent_checkbox
        render_choose_observations_section
        render_project_field
        render_skip_writeback_field if @admin
        render_details_panel
        submit(:submit.ti)
      end
    end

    def form_action
      inat_imports_path
    end

    private

    def project_admin_import? = @project_site.present?

    def may_import_others? = @super_importer || project_admin_import?

    def render_inat_username_field
      text_field(:inat_username,
                 label: :inat_username, size: 10, wrap_class: "mb-0")
    end

    def render_import_others_field
      checkbox_field(:import_others,
                     label: :inat_import_others,
                     wrap_class: "mt-1")
    end

    def render_create_skeletons_field
      checkbox_field(:create_skeletons,
                     label: :inat_create_skeletons,
                     help: :inat_create_skeletons_help.l,
                     wrap_class: "mt-1 ml-3")
    end

    def render_skip_writeback_field
      checkbox_field(:skip_inat_writeback,
                     label: :inat_skip_writeback,
                     wrap_class: "mt-3")
    end

    def render_choose_observations_section
      return render_project_scope_section if project_admin_import?

      render_method_choices
    end

    def render_method_choices
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

    # The project's configuration decides what this import covers, so
    # the search is shown -- a link, so an admin can read it on iNat
    # before importing it -- rather than offered as a choice. The
    # controller rebuilds it on submit; nothing here is read back.
    def render_project_scope_section
      hidden_field(:project_site)
      Panel(panel_class: "my-5") do |panel|
        panel.with_heading { plain(:inat_what_to_import.l) }
        panel.with_body do
          p { plain(:inat_import_project_scope.l(project: project_title)) }
          p(class: "mt-2") do
            render(Components::Link::External.new(
                     content: project_search_url, path: project_search_url
                   ))
          end
          render_recheck_all_field
        end
      end
    end

    def project_search_url
      @project_search_url ||= ::Inat::ProjectSearch.new(@project_site).url
    end

    def project_title = @project_site.project.title

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

    # Optional target project (#5259): the import files observations
    # into it and reconciles field slips against it.
    def render_project_field
      return render_fixed_project_field if project_admin_import?

      autocompleter_field(
        :inat_project, type: :project,
                       hidden_name: :inat_project_id,
                       hidden_value: model.inat_project_id,
                       label: :inat_project_label,
                       help: :inat_project_help.l,
                       wrap_class: "mt-3"
      )
    end

    # The project the admin started from, which is the project the
    # observations are filed into. Stated, not chosen.
    def render_fixed_project_field
      div(class: "mt-3") do
        strong { append_colon(:inat_project_label.l) }
        whitespace
        plain(project_title)
      end
    end

    # An admin importing a project brings in other people's
    # observations, so the licence their import applies to their
    # material is not the thing to consent to.
    def render_consent_checkbox
      label = if project_admin_import?
                :inat_import_consent_project
              else
                :inat_import_consent
              end
      checkbox_field(:consent, label: label, wrap_class: "mt-3")
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
        includes_item,
        :inat_details_fungi_only,
        :inat_details_data_fields,
        :inat_details_coordinates,
        :inat_details_location_name
      ]
    end

    # What an import covers, which for a project is other people's
    # observations as much as the admin's.
    def includes_item
      if project_admin_import?
        :inat_details_includes_project
      else
        :inat_details_includes_all
      end
    end
  end
end
