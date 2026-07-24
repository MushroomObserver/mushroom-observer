# frozen_string_literal: true

require("test_helper")

class ImageFragmentCopyrightTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_nothing_without_an_image
    html = render(Components::ImageFragment::Copyright.new(
                    user: @user, image: nil
                  ))

    assert_equal("", html)
  end

  def test_renders_free_text_holder_without_an_object
    @image.update(copyright_holder: "Bob Dobbs")

    html = render_copyright

    assert_html(html, ".image-copyright", text: "Bob Dobbs")
    assert_no_html(html, ".image-copyright a")
  end

  def test_renders_linked_uploader_when_holder_matches_their_legal_name
    @image.update(copyright_holder: @image.user.legal_name)

    html = render_copyright

    assert_html(html, ".image-copyright a[href='#{routes.user_path(
      @image.user_id
    )}']")
  end

  def test_hides_when_holder_matches_observation_owners_legal_name
    obs = observations(:coprinus_comatus_obs)
    @image.update(copyright_holder: obs.user.legal_name)

    html = render_copyright(object: obs)

    assert_equal("", html)
  end

  def test_shows_when_holder_differs_from_observation_owner
    obs = observations(:coprinus_comatus_obs)
    @image.update(copyright_holder: "Someone Else Entirely")
    assert_not_equal(@image.copyright_holder, obs.user.legal_name)

    html = render_copyright(object: obs)

    assert_html(html, ".image-copyright", text: "Someone Else Entirely")
  end

  private

  def render_copyright(object: nil)
    render(Components::ImageFragment::Copyright.new(
             user: @user, image: @image, object: object
           ))
  end
end
