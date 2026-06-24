# frozen_string_literal: true

require("test_helper")

module Views::Controllers::SpeciesLists
  # Tests for the species_list show-page details panel: date / observation
  # count / where / who / projects / notes, plus a download button in the
  # header row.
  class DetailsTest < ComponentTestCase
    def setup
      super
      # `species_lists(:unknown_species_list)` is the canonical fixture
      # the show-page system tests use; pulling it here keeps the
      # asserted user / where / etc. consistent with what users see.
      @species_list = species_lists(:unknown_species_list)
      @query = Query.lookup(:Observation,
                            species_lists: [@species_list.id])
    end

    def test_renders_panel_with_basic_metadata
      html = render_details

      assert_html(html, "#list_details")
      assert_html(html, ".panel.panel-default")
      # date row + download button line up via flex
      assert_html(html, ".d-flex.justify-content-between.align-items-center")
      # The four header labels — `assert_html(text:)` only checks the
      # first matching element, so use plain text assertions for the
      # presence-of-label checks (multiple `<b>` siblings in the panel).
      assert_html(html, "strong", text: "#{:WHEN.t}:")
      assert_includes(html, "#{:OBSERVATIONS.t}:")
      assert_includes(html, "#{:WHERE.t}:")
      assert_includes(html, "#{:WHO.t}:")
    end

    # Download button is `Button::Download` pointed at the irregular
    # `new_download_species_list_path` route — assert the rendered <a>
    # href to lock that route in (the helper has the only knowledge of
    # the path; if this regresses, the download button silently links
    # to the wrong action).
    def test_renders_download_button_with_correct_path
      html = render_details

      path = routes.new_download_species_list_path(
        id: @species_list.id
      )
      assert_html(html, "a[href='#{path}']")
      assert_html(html, "a span.glyphicon-download-alt")
    end

    def test_renders_projects_when_present
      project = projects(:eol_project)
      @species_list.projects << project unless
        @species_list.projects.include?(project)
      html = render_details(species_list: @species_list.reload)

      # The PROJECTS label only renders when the species_list has any.
      assert_includes(html, "#{:PROJECTS.t}:")
      # And each project shows up as a link_to_object.
      assert_html(html,
                  "a[href='#{routes.project_path(project.id)}']")
    end

    def test_does_not_render_projects_when_empty
      @species_list.projects.clear
      html = render_details(species_list: @species_list.reload)

      assert_not_includes(html, "#{:PROJECTS.t}:")
    end

    def test_renders_notes_when_present
      @species_list.update(notes: "These are notes")
      html = render_details

      assert_includes(html, "These are notes")
      assert_includes(html, "#{:NOTES.t}:")
    end

    def test_does_not_render_notes_when_blank
      @species_list.update(notes: "")
      html = render_details

      assert_not_includes(html, "#{:NOTES.t}:")
    end

    private

    def render_details(species_list: @species_list, query: @query)
      render(Views::Controllers::SpeciesLists::Details.new(
               species_list: species_list,
               query: query
             ))
    end
  end
end
