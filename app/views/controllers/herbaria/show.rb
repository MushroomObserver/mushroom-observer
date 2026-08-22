# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Herbarium show page: title + edit icons + pager + context-nav,
  # then a two-column body — left side has the records-link, the
  # `Show::CuratorTable` (when curators exist), the curator-add
  # form (when current user is a curator / admin) or the
  # curator-request link, plus optional notes + mailing address;
  # right side has the location map.
  class Show < Views::FullPageBase
    prop :herbarium, ::Herbarium

    def view_template
      add_show_title(@herbarium)
      add_edit_icons(@herbarium, current_user)
      add_pager_for(@herbarium)
      add_context_nav(::Tab::Herbarium::Show.new(q_param: q_param))
      container_class(:wide)

      render_mcp_block if @herbarium.mcp_searchable?
      Row { render_body_columns }
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
        Link(
          type: :get,
          name: :show_herbarium_herbarium_record_count.t(
            count: @herbarium.herbarium_records.length
          ),
          target: herbarium_records_path(herbarium: @herbarium.id),
          class: "herbarium_records_for_herbarium_link"
        )
      end
    end

    def render_curator_section
      div(class: "mt-3") do
        render(CuratorTable.new(herbarium: @herbarium)) \
          if @herbarium.curators.present?
        if curator_or_admin?
          render(AddCuratorForm.new(herbarium: @herbarium))
        else
          render_curator_request_link
        end
      end
    end

    def curator_or_admin?
      @herbarium.curator?(current_user) || in_admin_mode?
    end

    def render_curator_request_link
      Link(type: :get, name: :show_herbarium_curator_request.t,
           target: new_herbaria_curator_request_path(id: @herbarium.id),
           class: "new_herbaria_curator_request_link")
    end

    def render_notes
      div(class: "mt-3") do
        div(class: "font-weight-bold") { plain("#{:notes.ti}:") }
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
          plain("#{:location.ti}: #{@herbarium.location.text_name}")
        end
      end
    end

    def render_timestamps
      div(class: "mt-3", style: "max-width:#{map ? 930 : 600}px") do
        plain("#{:created_at.ti}: #{@herbarium.created_at.web_date}")
        br
        plain("#{:updated_at.ti}: #{@herbarium.updated_at.web_date}")
        br
      end
    end
  end
end
