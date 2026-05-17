# frozen_string_literal: true

require("test_helper")

# Tests for Components::ImagesToRemoveForm — bulk-removal matrix used
# by glossary term edit. Inherits Superform (PUT request, CSRF + _method
# emitted automatically).
class ImagesToRemoveFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @model = glossary_terms(:plane_glossary_term)
  end

  def test_renders_form_with_put_method_and_action
    html = render_form

    assert_html(html, "form[action='/test_action']")
    # Superform: explicit method: :put → POST + hidden _method=put.
    assert_html(html, "form[method='post']")
    assert_html(html, "input[type='hidden'][name='_method'][value='put']")
    assert_html(html, "input[type='hidden'][name='authenticity_token']")
  end

  def test_renders_one_checkbox_per_image_with_yes_no_values
    html = render_form

    @model.images.each do |image|
      # Visible checkbox: name="selected[<id>]", value="yes"
      assert_html(html, "input[type='checkbox']" \
                        "[name='selected[#{image.id}]'][value='yes']")
      # Hidden sidecar carries the "no" default for unchecked state.
      assert_html(html, "input[type='hidden']" \
                        "[name='selected[#{image.id}]'][value='no']")
    end
  end

  def test_each_checkbox_wrap_has_my_0_class
    html = render_form

    # Each per-image .checkbox wrapper gets `my-0` so BS3's default
    # 10px vertical margin doesn't leave visible gaps inside the
    # MatrixBox cell.
    @model.images.each do |image|
      assert_html(html, ".checkbox.my-0 input[name='selected[#{image.id}]']")
    end
  end

  def test_renders_submit_buttons_above_and_below_matrix
    html = render_form

    # Two submit inputs (top + bottom), both centered.
    submits = html.scan(/<input[^>]*type="submit"/).count
    assert_equal(2, submits,
                 "expected 2 submit buttons (top + bottom)")
  end

  def test_renders_matrix_with_one_box_per_image
    html = render_form

    # MatrixTable renders a `.row.list-unstyled` wrap; each MatrixBox
    # contains the image preview + checkbox for one image.
    assert_html(html, ".row.list-unstyled")
    assert_equal(@model.images.count, html.scan("matrix-box").count,
                 "expected one .matrix-box per image")
  end

  private

  def render_form
    render(Components::ImagesToRemoveForm.new(
             @model, form_action: "/test_action", user: @user
           ))
  end
end
