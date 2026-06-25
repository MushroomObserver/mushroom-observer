# frozen_string_literal: true

require("test_helper")

# Parity: old `link_to(..., class: "btn btn-default")` vs new `Button::Get`.
class OldReuseFormToggleLink < Components::Base
  def initialize(label:, url:)
    super()
    @label = label
    @url = url
  end

  def view_template
    link_to(@label, @url, class: "btn btn-default")
  end
end

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

  def test_toggle_link_parity
    label = :image_reuse_all_users.t
    url = "/observations/images/reuse/#{@obs.id}?all_users=1"

    old_html = render(OldReuseFormToggleLink.new(label: label, url: url))
    new_html = render(Components::Button::Get.new(target: url, name: label))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "reuse_form_toggle_link")
  end

  private

  def render_reuse_form(target:, all_users: false)
    render(Components::Image::ReuseForm.new(target: target,
                                            all_users: all_users))
  end
end
