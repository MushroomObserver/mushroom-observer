# frozen_string_literal: true

require("test_helper")

class Components::Image::ReuseFormTest < ComponentTestCase
  def setup
    super
    @obs = observations(:minimal_unknown_obs)
  end

  def test_renders_toggle_link
    html = render_reuse_form(target: @obs)

    assert_html(html, "a[href*='all_users']",
                text: :image_reuse_all_users.t.as_displayed)
  end

  private

  def render_reuse_form(target:, all_users: false)
    render(Components::Image::ReuseForm.new(target: target,
                                            all_users: all_users))
  end
end
