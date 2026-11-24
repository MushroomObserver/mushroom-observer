# frozen_string_literal: true

require("test_helper")

class ImageFragmentReuseToggleTest < ComponentTestCase
  def setup
    super
    @obs = observations(:minimal_unknown_obs)
  end

  def test_renders_select_with_both_options
    html = render_reuse_toggle(target: @obs)

    assert_html(html, "select[name='all_users']")
    assert_html(html, "option[value='0'][selected]",
                text: :image_reuse_just_yours.t.as_displayed)
    assert_html(html, "option[value='1']",
                text: :image_reuse_all_users.t.as_displayed)
  end

  def test_all_users_true_selects_the_all_images_option
    html = render_reuse_toggle(target: @obs, all_users: true)

    assert_html(html, "option[value='1'][selected]")
    assert_no_html(html, "option[value='0'][selected]")
  end

  def test_autosubmits_on_change
    html = render_reuse_toggle(target: @obs)

    url = routes.reuse_images_for_observation_path(@obs.id)
    assert_html(html,
                "form[data-controller='autosubmit'][action='#{url}']")
    assert_html(html, "select[data-action='change->autosubmit#submit']")
  end

  private

  def render_reuse_toggle(target:, all_users: false)
    render(Components::ImageFragment::ReuseToggle.new(
             target: target, all_users: all_users
           ))
  end
end
