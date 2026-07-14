# frozen_string_literal: true

# Action template for `HerbariumRecordsController#show`.
module Views::Controllers::HerbariumRecords
  class Show < Views::FullPageBase
    prop :herbarium_record, ::HerbariumRecord
    prop :user, ::User

    def view_template
      add_show_title(@herbarium_record)
      add_edit_icons(@herbarium_record, @user)
      add_pager_for(@herbarium_record)
      add_context_nav(
        Tab::HerbariumRecord::ShowActions.new(q_param: q_param)
      )
      column_classes(:six)
      container_class(:full)

      # Top text details + bottom footer both kept at
      # `container-text` width; the obs-matrix between them runs
      # full-width inside the page's full-width `<main>`.
      Container(width: :text) { render_details }
      render_observation_matrix
      Container(width: :text) do
        render(::Views::Layouts::ObjectFooter.new(
                 obj: @herbarium_record, minimal: true
               ))
      end
    end

    private

    def render_details
      ContentPadded(id: "herbarium_record_details") do
        p do
          render_field_lines
          render_collection_link if herbarium&.web_searchable?
        end
        render_notes
      end
    end

    def render_field_lines
      render_herbarium_field
      render_initial_det_field
      render_field(:herbarium_record_accession_number.t,
                   @herbarium_record.accession_number)
      render_user_field
    end

    def render_herbarium_field
      trusted_html(:HERBARIUM.t)
      plain(": ")
      a(href: url_for(herbarium.show_link_args)) do
        trusted_html(herbarium.name.t)
      end
      br
    end

    def render_initial_det_field
      trusted_html(:herbarium_record_initial_det.t)
      plain(": ")
      i { plain(@herbarium_record.initial_det) }
      br
    end

    def render_field(label, value)
      trusted_html(label)
      plain(": #{value}")
      br
    end

    def render_user_field
      trusted_html(:herbarium_record_user.t)
      plain(": ")
      Link(type: :user, user: @herbarium_record.user)
      br
    end

    def render_collection_link
      Link(type: :external,
           content: "#{herbarium.code} #{:herbarium_record_collection.t}",
           path: herbarium.mcp_url(@herbarium_record.accession_number))
      br
    end

    def render_notes
      return if @herbarium_record.notes.blank?

      trusted_html("#{:NOTES.l}:\n\n#{@herbarium_record.notes}".tpl)
    end

    def render_observation_matrix
      render(Components::Matrix::Table.new(
               objects: @herbarium_record.observations.to_a, user: @user
             ))
    end

    def herbarium
      @herbarium ||= @herbarium_record.herbarium
    end
  end
end
