# frozen_string_literal: true

require("test_helper")

# Tests for `Components::TargetLocationModal` — the on-demand modal
# rendered by `Projects::ViolationsController#target_location_modal`
# (#4304). The component picks between two branches:
#   - obs has usable suffixes → form_content slot owned by
#     `TargetLocationForm`.
#   - obs's `where` resolves to no suffixes (country-only) → static
#     "no usable suffixes" body + Cancel-only footer.
class TargetLocationModalTest < ComponentTestCase
  def setup
    super
    @project = projects(:rare_fungi_project)
    @obs = observations(:falmouth_2023_09_obs)
  end

  def test_renders_modal_with_form_content_for_obs_with_suffixes
    html = render_modal(obs: @obs)
    modal_id = Components::TargetLocationModal.modal_id_for(@obs)

    assert_html(html, "##{modal_id}.modal")
    assert_html(html, "##{modal_id} .modal-title",
                text: :form_violations_modal_target_location_title.l)
    # form_content slot ⇒ the form's body+footer divs are both inside
    # the <form> tag (rather than sibling .modal-body/.modal-footer).
    assert_html(html, "##{modal_id} form > .modal-body")
    assert_html(html, "##{modal_id} form > .modal-footer")
    # Form posts add_target_location with the obs id.
    assert_html(html,
                "##{modal_id} " \
                "input[type='hidden'][name='project[do]']" \
                "[value='add_target_location']")
    assert_html(html,
                "##{modal_id} " \
                "input[type='hidden'][name='project[obs_id]']" \
                "[value='#{@obs.id}']")
  end

  def test_renders_no_suffixes_branch_for_country_only_where
    @obs.update!(location_id: nil, where: "USA")
    html = render_modal(obs: @obs)
    modal_id = Components::TargetLocationModal.modal_id_for(@obs)

    assert_html(html, "##{modal_id} .modal-body p",
                text: :form_violations_modal_target_location_no_suffixes.l)
    assert_html(html,
                "##{modal_id} .modal-footer button[data-dismiss='modal']",
                text: :CANCEL.l)
    # No form when there's nothing to submit.
    assert_no_html(html, "##{modal_id} form")
  end

  def test_modal_does_not_render_its_own_backdrop
    # The modal-toggle Stimulus controller calls
    # `$(_modal).modal('show')` after appending the modal, and
    # Bootstrap creates its own backdrop at that point. If the modal
    # also rendered a backdrop in its initial HTML, Bootstrap's
    # dismiss flow would only remove its own — leaving a stuck
    # `.modal-backdrop` over the page.
    html = render_modal(obs: @obs)

    assert_no_html(html, ".modal-backdrop")
  end

  def test_modal_id_for_class_method_matches_instance_id
    # Other components (e.g. the trigger link in ProjectViolationsForm)
    # need a stable way to compute the modal id without instantiating
    # the modal. Locking down the helper here.
    assert_equal("location_target_modal_#{@obs.id}",
                 Components::TargetLocationModal.modal_id_for(@obs))
  end

  private

  def render_modal(obs:, project: @project, user: nil)
    render(Components::TargetLocationModal.new(
             project: project, obs: obs,
             user: user || project.user
           ))
  end
end
