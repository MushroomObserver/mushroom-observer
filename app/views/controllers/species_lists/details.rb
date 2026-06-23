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
          strong { plain("#{:WHEN.t}:") }
          whitespace
          plain(@species_list.when.web_date)
        end
        div { render_download_button }
      end
    end

    # The species_list download path is irregular
    # (`new_download_species_list_path`, not `download_species_list_path`)
    # so build the path explicitly and pass it to `CRUDButton::Download`
    # as a String target.
    def render_download_button
      render(Components::CRUDButton::Download.new(
               target: new_download_species_list_path(id: @species_list.id)
             ))
    end

    def render_observation_count
      div do
        b { plain("#{:OBSERVATIONS.t}:") }
        whitespace
        plain(@query.num_results.to_s)
      end
    end

    # `location_link` raises if `@species_list.where` is blank — fall
    # back to a plain `:UNKNOWN.t` label in that case.
    def render_where
      div do
        b { plain("#{:WHERE.t}:") }
        whitespace
        begin
          render(Components::Link::Object::Location.new(
                   where: @species_list.where,
                   location: @species_list.location, click: true
                 ))
        rescue StandardError
          plain(:UNKNOWN.t)
        end
      end
    end

    def render_who
      div do
        b { plain("#{:WHO.t}:") }
        whitespace
        render(Components::Link::Object::User.new(user: @species_list.user))
      end
    end

    def render_projects
      div do
        b { plain("#{:PROJECTS.t}:") }
        whitespace
        @species_list.projects.each_with_index do |project, idx|
          plain(" | ") if idx.positive?
          render(Components::Link::Object::Base.new(object: project))
        end
      end
    end

    # Notes get the `*NOTES:* …`-into-textile treatment;
    # render through `trusted_html` because `.tpl` returns already-safe markup.
    def render_notes
      div do
        trusted_html("*#{:NOTES.t}:* #{@species_list.notes}".tpl)
      end
    end
  end
end
