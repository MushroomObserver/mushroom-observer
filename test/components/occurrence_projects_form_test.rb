# frozen_string_literal: true

require("test_helper")

class OccurrenceProjectsFormTest < ComponentTestCase
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
    assert_html(html, ".modal-body > p",
                text: :occurrence_resolve_projects_intro.l)

    # Project list heading
    assert_html(html, ".modal-body > strong", text: "#{:PROJECTS.l}:")
    assert_html(html, "a[href='/projects/#{@project.id}']",
                text: @project.title)

    # Form posts to occurrences_path
    assert_html(html, "form[action='/occurrences'][method='post']")

    # Hidden fields for selected observations — namespaced under
    # `occurrence_projects[*]` (the FormObject's param key).
    # OccurrencesController#create reads via `occurrence_form_param` so
    # it accepts either this or the new-form's `occurrence[*]` shape.
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence_projects[observation_ids][]']" \
                "[value='#{@obs1.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence_projects[observation_ids][]']" \
                "[value='#{@obs2.id}']")
    # observation_id (source obs) stays top-level — matches the new-
    # form's contract; the controller reads `params[:observation_id]`
    # for `find_source_observation!`.
    assert_html(html,
                "input[type='hidden']" \
                "[name='observation_id']" \
                "[value='#{@obs1.id}']")
    assert_html(html,
                "input[type='hidden']" \
                "[name='occurrence_projects" \
                "[primary_observation_id]']" \
                "[value='#{@obs1.id}']")

    # Cancel link points to new_occurrence_path
    assert_html(
      html,
      "a.btn[href='/occurrences/new" \
      "?observation_id=#{@obs1.id}']",
      text: :CANCEL.l
    )

    # Skip button — proceed without backfilling projects
    assert_html(html,
                "button[type='submit']" \
                "[name='occurrence_projects[resolution]']" \
                "[value='skip']",
                text: :SKIP.l)

    # Add All button
    assert_html(html,
                "button[type='submit']" \
                "[name='occurrence_projects[resolution]']" \
                "[value='add_all']",
                text: :ADD_ALL.l)
  end

  def test_edit_flow
    occ = Occurrence.create!(user: @user,
                             primary_observation: @obs1)
    @obs1.update!(occurrence: occ)
    gaps = { projects: [@project] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, occurrence: occ
    )

    # Form PATCHes the nested projects resource:
    # /occurrences/:occurrence_id/projects → Occurrences::ProjectsController#update.
    assert_html(
      html,
      "form[action='/occurrences/#{occ.id}/projects'][method='post']"
    )
    # PATCH is emitted via Rails' `_method` override (HTML forms can
    # only natively POST or GET). The FormObject's `for_update: true`
    # flips `persisted?` so Superform picks PATCH.
    assert_html(html, "input[name='_method'][value='patch']")

    # Cancel link points to occurrence show page
    assert_html(
      html, "a.btn[href='/occurrences/#{occ.id}']",
      text: :CANCEL.l
    )

    # Skip button — leave projects alone, redirect to occurrence show
    assert_html(html,
                "button[type='submit']" \
                "[name='occurrence_projects[resolution]']" \
                "[value='skip']",
                text: :SKIP.l)

    # Add All button
    assert_html(html,
                "button[type='submit']" \
                "[name='occurrence_projects[resolution]']" \
                "[value='add_all']",
                text: :ADD_ALL.l)
  end

  def test_no_project_list_when_empty
    gaps = { projects: [] }
    html = render_resolve_form(
      gaps: gaps, primary: @obs1, selected: [@obs1]
    )

    # Intro text still renders
    assert_html(html, ".modal-body > p",
                text: :occurrence_resolve_projects_intro.l)

    # No project list heading
    assert_no_html(html, ".modal-body > strong")
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
      "[name='occurrence_projects[primary_observation_id]']"
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
      "[name='occurrence_projects[observation_ids][]']"
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
    assert_html(html,
                "form > .modal-footer > button[value='add_all']",
                text: :ADD_ALL.l)
    assert_html(html,
                "form > .modal-footer > button[value='skip']",
                text: :SKIP.l)
    assert_html(html, "form > .modal-footer > a[data-dismiss='modal']",
                text: :CANCEL.l)
  end

  def test_owns_modal_sections_class_method_returns_true
    # ModalTurboForm and similar wrappers auto-detect this to choose
    # Modal's :form_content slot. Locks the contract in.
    assert(Components::OccurrenceProjectsForm.owns_modal_sections?)
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
    render(Components::OccurrenceProjectsForm.new(
             gaps: gaps, primary: primary,
             selected: selected, occurrence: occurrence
           ))
  end
end
