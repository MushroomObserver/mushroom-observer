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

  def test_create_flow_hidden_fields_and_buttons
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1,
      selected: [@obs1, @obs2]
    )

    doc = Nokogiri::HTML(html)
    # Authenticity token present
    token = doc.at_css(
      "input[type='hidden']" \
      "[name='authenticity_token']"
    )
    assert(token, "Expected authenticity token field")

    # Primary observation hidden field
    primary_field = doc.at_css(
      "input[type='hidden']" \
      "[name='occurrence[primary_observation_id]']"
    )
    assert(primary_field,
           "Expected primary observation hidden field")
    assert_equal(@obs1.id.to_s, primary_field["value"])

    # observation_id hidden field
    obs_id_field = doc.at_css(
      "input[type='hidden']" \
      "[name='occurrence[observation_id]']"
    )
    assert(obs_id_field,
           "Expected observation_id hidden field")
    assert_equal(@obs1.id.to_s, obs_id_field["value"])
  end

  def test_edit_flow_authenticity_token
    occ = Occurrence.create!(
      user: @user, primary_observation: @obs1
    )
    @obs1.update!(occurrence: occ)
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, occurrence: occ
    )

    doc = Nokogiri::HTML(html)
    token = doc.at_css(
      "input[type='hidden']" \
      "[name='authenticity_token']"
    )
    assert(token, "Expected authenticity token field")

    # No observation_ids hidden fields in edit flow
    obs_ids = doc.css(
      "input[type='hidden']" \
      "[name='observation_ids[]']"
    )
    assert_equal(0, obs_ids.size,
                 "Edit flow should not have obs hidden fields")
  end

  def test_multiple_projects_listed
    proj2 = projects(:bolete_project)
    gaps = { projects: [@project, proj2] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, selected: [@obs1]
    )

    assert_html(
      html, "a[href='/projects/#{@project.id}']"
    )
    assert_html(
      html, "a[href='/projects/#{proj2.id}']"
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
