# frozen_string_literal: true

require("test_helper")

class ImageFragmentReuseFormTest < ComponentTestCase
  def setup
    super
    @obs = observations(:minimal_unknown_obs)
  end

  def test_renders_id_field_and_submit
    html = render_reuse_form(target: @obs)

    assert_html(html, "input[name='image_reuse[img_id]']")
    assert_html(html, "button[type='submit']",
                text: :image_reuse_reuse.l.as_displayed)
  end

  private

  def render_reuse_form(target:, all_users: false)
    render(Components::ImageFragment::ReuseForm.new(target: target,
                                                    all_users: all_users))
  end
end
