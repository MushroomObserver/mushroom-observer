# frozen_string_literal: true

require("test_helper")

class BannerFormTest < ComponentTestCase
  def setup
    super
    @banner = Banner.current || Banner.new
  end

  def test_renders_form_structure
    html = render_form

    # Form structure
    assert_html(html, "#banner_form")
    assert_html(html, "form[action='/admin/banners']")
    assert_html(html, "form[method='post']")

    # Textarea field for message
    assert_html(html, "textarea[name='banner[message]']")

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:banner_update.t}']")
  end

  def test_renders_with_existing_banner
    @banner = banners(:one)
    html = render_form

    assert_includes(html, @banner.message)
  end

  private

  def render_form
    render(Components::BannerForm.new(@banner))
  end
end
