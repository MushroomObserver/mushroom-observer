# frozen_string_literal: true

require "test_helper"

class ProjectFieldSlipFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @project = projects(:eol_project)
  end

  def test_new_form
    html = render_form

    # Form structure
    assert_html(html, "form[action*='field_slips']")
    assert_html(html, "form[data-turbo='true']")

    # Fields with name attributes
    assert_html(html,
                "input[type='number']" \
                "[name='project_field_slip[field_slips]']")
    assert_html(html,
                "input[type='checkbox']" \
                "[name='project_field_slip[one_per_page]']")

    # Labels
    assert_includes(html, :field_slips.l)
    assert_includes(html, :field_slips_one_per_page.t)

    # Submit button
    assert_html(html,
                "input[type='submit'][value='#{:CREATE.l}']")
  end

  def test_default_field_slip_count
    html = render_form(field_slips: 6)

    assert_html(html,
                "input[name='project_field_slip[field_slips]']" \
                "[value='6']")
  end

  def test_zero_field_slip_count
    html = render_form(field_slips: 0)

    assert_html(html,
                "input[name='project_field_slip[field_slips]']" \
                "[value='0']")
  end

  private

  def render_form(field_slips: 6)
    User.current = @user
    model = FormObject::ProjectFieldSlip.new(
      field_slips: field_slips
    )
    render(Components::ProjectFieldSlipForm.new(
             model, project: @project
           ))
  end
end
