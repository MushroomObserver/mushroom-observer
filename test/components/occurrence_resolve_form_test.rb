# frozen_string_literal: true

require("test_helper")

class OccurrenceResolveFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @project = projects(:eol_project)
  end

  def test_create_flow
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, selected: [@obs1, @obs2]
    )

    # Intro text
    assert_includes(html, :occurrence_resolve_projects_intro.l)

    # Project list
    assert_includes(
      html, :occurrence_resolve_projects_projects.l
    )
    assert_html(html, "a[href='/projects/#{@project.id}']",
                text: @project.title)

    # Form posts to occurrences_path
    assert_html(html, "form[action='/occurrences'][method='post']")

    # Hidden fields for selected observations
    assert_html(html,
                "input[type='hidden']" \
                "[name='observation_ids[]']" \
                "[value='#{@obs1.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='observation_ids[]']" \
                "[value='#{@obs2.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence[observation_id]']" \
                "[value='#{@obs1.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence[primary_observation_id]']" \
                "[value='#{@obs1.id}']")

    # Cancel link points to new_occurrence_path
    assert_html(
      html,
      "a.btn[href='/occurrences/new" \
      "?observation_id=#{@obs1.id}']",
      text: :occurrence_resolve_projects_cancel.l
    )

    # Add All button with project_resolution name
    assert_html(html,
                "button[type='submit']" \
                "[name='project_resolution']" \
                "[value='add_all']",
                text: :occurrence_resolve_projects_add_all.l)
  end

  def test_edit_flow
    occ = Occurrence.create!(user: @user,
                             primary_observation: @obs1)
    @obs1.update!(occurrence: occ)
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, occurrence: occ
    )

    # Form posts to resolve_projects_occurrence_path
    assert_html(
      html,
      "form[action='/occurrences/#{occ.id}" \
      "/resolve_projects'][method='post']"
    )

    # Cancel link points to occurrence show page
    assert_html(
      html, "a.btn[href='/occurrences/#{occ.id}']",
      text: :occurrence_resolve_projects_cancel.l
    )

    # Add All button with resolution name (not project_resolution)
    assert_html(html,
                "button[type='submit']" \
                "[name='resolution']" \
                "[value='add_all']",
                text: :occurrence_resolve_projects_add_all.l)
  end

  def test_no_project_list_when_empty
    gaps = { projects: [] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, selected: [@obs1]
    )

    # Intro text still renders
    assert_includes(html, :occurrence_resolve_projects_intro.l)

    # No project list heading
    assert_not_includes(
      html, :occurrence_resolve_projects_projects.l
    )
  end

  private

  def render_resolve_form(gaps:, primary:, selected: nil,
                          occurrence: nil)
    render(Components::OccurrenceResolveForm.new(
             gaps: gaps, primary: primary,
             selected: selected, occurrence: occurrence
           ))
  end
end
