# frozen_string_literal: true

# Details panel for the species_list show page. Renders date / observation
# count / where / who / projects / notes inside a `Components::Panel`,
# with a download button in the header row.
module Views::Controllers::SpeciesLists
  class Details < Views::Base
    def initialize(species_list:, query:)
      super()
      @species_list = species_list
      @query = query
    end

    def view_template
      render(Components::Panel.new(
               panel_id: "list_details",
               panel_class: "mt-3 mb-0"
             )) do |panel|
        panel.with_body { render_body }
      end
    end

    private

    def render_body
      render_header_row
      render_observation_count
      render_where
      render_who
      render_projects if @species_list.projects.any?
      render_notes if @species_list.notes.present?
    end

    # Date label + value on the left, download button on the right.
    def render_header_row
      div(class: "d-flex justify-content-between align-items-center") do
        div do
          strong { plain("#{:when.ti}:") }
          whitespace
          plain(@species_list.when.web_date)
        end
        div { render_download_button }
      end
    end

    # The species_list download path is irregular
    # (`new_download_species_list_path`, not `download_species_list_path`)
    # so build the path explicitly and pass it to `Button::Download`
    # as a String target.
    def render_download_button
      Button(
        type: :download,
        target: new_download_species_list_path(id: @species_list.id),
        variant: :strip
      )
    end

    def render_observation_count
      div do
        b { plain("#{:observations.ti}:") }
        whitespace
        plain(@query.num_results.to_s)
      end
    end

    # `location_link` raises if `@species_list.where` is blank — fall
    # back to a plain `:unknown.ti` label in that case.
    def render_where
      div do
        b { plain("#{:where.ti}:") }
        whitespace
        begin
          Link(type: :location,
               where: @species_list.where,
               location: @species_list.location, click: true)
        rescue StandardError
          plain(:unknown.ti)
        end
      end
    end

    def render_who
      div do
        b { plain("#{:who.ti}:") }
        whitespace
        Link(type: :user, user: @species_list.user)
      end
    end

    def render_projects
      div do
        b { plain("#{:projects.ti}:") }
        whitespace
        @species_list.projects.each_with_index do |project, idx|
          plain(" | ") if idx.positive?
          Link(type: :object, object: project)
        end
      end
    end

    # Notes get the `*NOTES:* …`-into-textile treatment;
    # render through `trusted_html` because `.tpl` returns already-safe markup.
    def render_notes
      div do
        trusted_html("*#{:notes.ti}:* #{@species_list.notes}".tpl)
      end
    end
  end
end
