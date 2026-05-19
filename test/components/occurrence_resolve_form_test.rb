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

    # Hidden fields for selected observations — must use the namespaced
    # `occurrence[observation_ids][]` shape because OccurrencesController#create
    # reads `params.dig(:occurrence, :observation_ids)` (PR #4250).
    # Flat `observation_ids[]` would be silently ignored and the controller
    # would flash "must include at least one additional observation".
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence[observation_ids][]']" \
                "[value='#{@obs1.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence[observation_ids][]']" \
                "[value='#{@obs2.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='observation_id']" \
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
      "[name='observation_id']"
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
      "[name='occurrence[observation_ids][]']"
    )
    assert_equal(0, obs_ids.size,
                 "Edit flow should not have obs hidden fields")
  end

  def test_form_wraps_modal_body_and_modal_footer
    # Per the Modal :form_content slot pattern (#4293), the form spans
    # both `.modal-body` (intro + project list) and `.modal-footer`
    # (cancel + submit) — submit lives in the footer but is naturally
    # inside the form.
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, selected: [@obs1, @obs2]
    )

    assert_html(html, "form > .modal-body > p",
                text: :occurrence_resolve_projects_intro.l)
    # Project list uses `ul.list-unstyled` (no bullets, no left
    # padding). Each row is a flex container with a clickable id-badge
    # button (Stimulus clipboard target) followed by the project link.
    assert_html(html, "form > .modal-body > ul.list-unstyled > li.d-flex")
    assert_html(html,
                ".modal-body > ul > li > button.badge.badge-id" \
                "[data-controller='clipboard']",
                text: @project.id.to_s)
    assert_html(html, ".modal-body > ul > li > a",
                text: @project.title)
    assert_html(html, "form > .modal-footer > button[type='submit']",
                text: :occurrence_resolve_projects_add_all.l)
    assert_html(html, "form > .modal-footer > a[data-dismiss='modal']",
                text: :occurrence_resolve_projects_cancel.l)
  end

  def test_owns_modal_sections_class_method_returns_true
    # ModalTurboForm and similar wrappers auto-detect this to choose
    # Modal's :form_content slot. Locks the contract in.
    assert(Components::OccurrenceResolveForm.owns_modal_sections?)
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
