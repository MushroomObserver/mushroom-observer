# frozen_string_literal: true

require("test_helper")

class OccurrenceResolveModalTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @project = projects(:eol_project)
  end

  def test_modal_structure
    gaps = { projects: [@project] }
    html = render_modal(
      gaps: gaps, primary: @obs1, selected: [@obs1, @obs2]
    )

    # Backdrop
    assert_html(html, "div.modal-backdrop.fade.in")

    # Modal wrapper with correct attributes
    assert_html(
      html,
      "div.modal.fade.in#modal_resolve_projects" \
      "[role='dialog']"
    )
    doc = Nokogiri::HTML(html)
    modal = doc.at_css("#modal_resolve_projects")
    assert_equal("display: block;", modal["style"])
    assert_equal("modal", modal["data-controller"])
    assert_equal(@user.id.to_s,
                 modal["data-modal-user-value"])

    # Modal dialog and content
    assert_html(html, "div.modal-dialog.modal-lg")
    assert_html(html, "div.modal-content")

    # Header with title and close button
    assert_html(html, "div.modal-header")
    assert_html(
      html, "h4.modal-title",
      text: :occurrence_resolve_projects_title.l
    )
    assert_html(html,
                "button.close[data-dismiss='modal']")

    # Body contains the resolve form
    assert_html(html, "div.modal-body")
    assert_includes(
      html, :occurrence_resolve_projects_intro.l
    )
    assert_html(html, "form[action='/occurrences']")
  end

  def test_modal_edit_flow
    occ = Occurrence.create!(user: @user,
                             primary_observation: @obs1)
    @obs1.update!(occurrence: occ)
    gaps = { projects: [@project] }
    html = render_modal(
      gaps: gaps, primary: @obs1, occurrence: occ
    )

    # Body contains edit form pointing to occurrence
    assert_html(
      html,
      "form[action='/occurrences/#{occ.id}" \
      "/resolve_projects']"
    )
  end

  private

  def render_modal(gaps:, primary:, selected: nil,
                   occurrence: nil)
    render(Components::OccurrenceResolveModal.new(
             gaps: gaps, primary: primary,
             user: @user,
             selected: selected,
             occurrence: occurrence
           ))
  end
end
