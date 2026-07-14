# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Herbarium show page: title + edit icons + pager + context-nav,
  # then a two-column body — left side has the records-link, the
  # `Show::CuratorTable` (when curators exist), the curator-add
  # form (when current user is a curator / admin) or the
  # curator-request link, plus optional notes + mailing address;
  # right side has the location map.
  class Show < Views::FullPageBase
    include ::Phlex::Rails::Helpers::FormAuthenticityToken

    prop :herbarium, ::Herbarium

    def view_template
      add_show_title(@herbarium)
      add_edit_icons(@herbarium, current_user)
      add_pager_for(@herbarium)
      add_context_nav(::Tab::Herbarium::Show.new(q_param: q_param))
      container_class(:wide)

      render_mcp_block if @herbarium.mcp_searchable?
      div(class: "row") { render_body_columns }
      render_timestamps
    end

    private

    def map
      @map ||= @herbarium.location
    end

    def render_mcp_block
      div(id: "mcp_number", class: "mt-3") do
        span(class: "font-weight-bold") { plain(:herbarium_mcp_db.t) }
        plain(": #{@herbarium.mcp_collid}")
      end
    end

    # --- Left + right columns --------------------------------------

    def render_body_columns
      Column(xs: 12, sm: map ? 8 : 12) do
        render_left_column
      end
      render_right_column if map
    end

    def render_left_column
      render_records_link
      render_curator_section
      render_notes if @herbarium.description.present?
      render_mailing_address if @herbarium.mailing_address.present?
    end

    def render_records_link
      div(class: "mt-3") do
        link_to(
          :show_herbarium_herbarium_record_count.t(
            count: @herbarium.herbarium_records.length
          ),
          herbarium_records_path(herbarium: @herbarium.id),
          class: "herbarium_records_for_herbarium_link"
        )
      end
    end

    def render_curator_section
      div(class: "mt-3") do
        render(CuratorTable.new(herbarium: @herbarium)) \
          if @herbarium.curators.present?
        if curator_or_admin?
          render_add_curator_form
        else
          render_curator_request_link
        end
      end
    end

    def curator_or_admin?
      @herbarium.curator?(current_user) || in_admin_mode?
    end

    # The form posts a top-level `:add_curator` param (NOT nested
    # under a FormObject). Hand-rolled `<form>` so we don't get
    # Superform's `<form_name>[:add_curator]` namespacing.
    def render_add_curator_form
      form(action: herbaria_curators_path(id: @herbarium, q: q_param),
           method: "post",
           id: "herbarium_curators_form") do
        input(type: "hidden", name: "authenticity_token",
              value: form_authenticity_token)
        div(class: "form-inline mt-3") do
          render(::Components::ApplicationForm::AutocompleterField.new(
                   ::Components::ApplicationForm::FieldProxy.new(
                     nil, :add_curator, nil
                   ),
                   type: :user, label: false
                 ))
          label(for: "add_curator") do
            Button(
              type: :submit,
              name: :show_herbarium_add_curator.t,
              html_name: "commit"
            )
          end
        end
      end
    end

    def render_curator_request_link
      link_to(:show_herbarium_curator_request.t,
              new_herbaria_curator_request_path(id: @herbarium.id),
              class: "new_herbaria_curator_request_link")
    end

    def render_notes
      div(class: "mt-3") do
        div(class: "font-weight-bold") { plain("#{:NOTES.t}:") }
        trusted_html(@herbarium.description.tpl)
      end
    end

    def render_mailing_address
      div(class: "mt-3") do
        div(class: "font-weight-bold") do
          plain("#{:herbarium_mailing_address.t}:")
        end
        trusted_html(@herbarium.mailing_address.tp)
      end
    end

    def render_right_column
      Column(xs: 12, sm: 4, class: "mt-3", style: "max-width:320px") do
        div(class: "mb-3") do
          Map(objects: [@herbarium.location])
        end
        p(id: "herbarium_location") do
          plain("#{:LOCATION.l}: #{@herbarium.location.text_name}")
        end
      end
    end

    def render_timestamps
      div(class: "mt-3", style: "max-width:#{map ? 930 : 600}px") do
        plain("#{:CREATED_AT.t}: #{@herbarium.created_at.web_date}")
        br
        plain("#{:UPDATED_AT.t}: #{@herbarium.updated_at.web_date}")
        br
      end
    end
  end
end
