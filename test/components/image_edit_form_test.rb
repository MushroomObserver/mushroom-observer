# frozen_string_literal: true

require("test_helper")

# Tests for Components::ImageEditForm — the Phlex Superform that
# replaces app/views/controllers/observations/images/edit.html.erb.
class ImageEditFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @licenses = [["CC-BY", 1], ["CC-BY-SA", 2]]
  end

  def test_form_action_and_method
    img = images(:agaricus_campestris_image)
    html = render_form(image: img)

    # PUT update via the standard image_path. The form's `_method=patch`
    # hidden carries the verb (Superform's default for persisted records).
    assert_html(html, "form[action='/images/#{img.id}']")
    assert_html(html,
                "input[type='hidden'][name='_method'][value='patch']")
  end

  def test_renders_core_fields
    img = images(:agaricus_campestris_image)
    html = render_form(image: img)

    assert_html(html, "input[name='image[copyright_holder]']")
    assert_html(html, "input[name='image[original_name]']")
    assert_html(html, "select[name='image[license_id]']")
    assert_html(html, "textarea[name='image[notes]']")
    # date_select-style when field (yyyy/mm/dd selects + year input).
    assert_html(html, "select[name='image[when(2i)]']")
  end

  def test_license_select_shows_name_not_id
    img = images(:agaricus_campestris_image)
    html = render_form(image: img)

    # Each option's value attribute must be the numeric ID and
    # its visible text must be the license name — not the reverse.
    @licenses.each do |name, id|
      selector = "select[name='image[license_id]'] option[value='#{id}']"
      assert_html(html, selector, text: name)
    end
  end

  def test_no_project_section_when_no_projects
    img = images(:agaricus_campestris_image)
    html = render_form(image: img, projects: [])

    assert_no_html(html, "input[name='image[project_ids][]']")
  end

  def test_project_checkboxes_array_shape
    img = images(:in_situ_image)
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    # Force the model state so checkedness comes from project_ids.
    img.projects = [proj1]
    html = render_form(image: img, projects: [proj1, proj2])

    # Sentinel hidden input ensures the key is always present even
    # when every checkbox is unchecked.
    assert_html(
      html,
      "input[type='hidden'][name='image[project_ids][]'][value='']",
      count: 1
    )
    # Each checkbox: array-shape name + value=<id>. proj1 checked,
    # proj2 unchecked.
    assert_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{proj1.id}'][checked]",
      count: 1
    )
    assert_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{proj2.id}']",
      count: 1
    )
    assert_no_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{proj2.id}'][checked]"
    )
  end

  def test_submitted_project_ids_overrides_model_for_checkedness
    img = images(:in_situ_image)
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    img.projects = [proj1]
    html = render_form(image: img, projects: [proj1, proj2],
                       submitted_project_ids: [proj2.id.to_s])

    # proj2 is checked (matches submitted), proj1 isn't (despite the
    # model still being attached to proj1).
    assert_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{proj2.id}'][checked]"
    )
    assert_no_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{proj1.id}'][checked]"
    )
  end

  def test_project_checkbox_disabled_for_non_owner_non_member
    # Image is mary's; user is dick (non-owner). dick is NOT a member
    # of eol_project but IS a member of bolete_project.
    img = images(:in_situ_image)
    eol = projects(:eol_project)
    bolete = projects(:bolete_project)
    html = render_form(image: img, user: users(:dick),
                       projects: [eol, bolete])

    assert_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{eol.id}'][disabled]"
    )
    assert_no_html(
      html,
      "input[type='checkbox']" \
      "[name='image[project_ids][]'][value='#{bolete.id}'][disabled]"
    )
  end

  def test_renders_two_submit_buttons
    img = images(:agaricus_campestris_image)
    html = render_form(image: img)

    # One above the fields, one in the footer.
    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']",
                count: 2)
  end

  private

  def render_form(image:, user: @user, licenses: @licenses, projects: [],
                  submitted_project_ids: nil)
    render(Components::ImageEditForm.new(
             image,
             user: user,
             licenses: licenses,
             projects: projects,
             submitted_project_ids: submitted_project_ids
           ))
  end
end
