# frozen_string_literal: true

# Action template for `HerbariumRecordsController#show`. Replaces
# `app/views/controllers/herbarium_records/show.html.erb`.
module Views::Controllers::HerbariumRecords
  class Show < Views::Base
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

      # Keep the text details + Timestamps at `container-text` width;
      # let the obs-matrix below run full-width inside the page's
      # full-width `<main>`.
      div(class: "container-text") do
        render_details
        render(Components::Timestamps.new(object: @herbarium_record))
      end
      render_observation_matrix
    end

    private

    def render_details
      render(Components::ContentPadded.new(id: "herbarium_record_details")) do
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
      render(Components::UserLink.new(user: @herbarium_record.user))
      br
    end

    def render_collection_link
      a(href: herbarium.mcp_url(@herbarium_record.accession_number),
        target: "_blank", rel: "noopener") do
        plain("#{herbarium.code} ")
        trusted_html(:herbarium_record_collection.t)
      end
      br
    end

    def render_notes
      return if @herbarium_record.notes.blank?

      trusted_html("#{:NOTES.l}:\n\n#{@herbarium_record.notes}".tpl)
    end

    def render_observation_matrix
      render(Components::MatrixTable.new(
               objects: @herbarium_record.observations.to_a, user: @user
             ))
    end

    def herbarium
      @herbarium ||= @herbarium_record.herbarium
    end
  end
end
