# frozen_string_literal: true

require "test_helper"

class AccountProfileFormTest < ComponentTestCase
  def setup
    super
    @license = licenses(:ccby)
    @licenses = License.available_names_and_ids
  end

  # User without a profile image: upload section uses "Upload photo:" label
  # and all upload fields submit under the top-level upload[] namespace.
  def test_user_without_image
    user = users(:mary)
    html = render_form(user:)

    # Multipart encoding
    assert_html(html, "form[enctype='multipart/form-data']")

    # Form target
    assert_html(html, "form[action='/account/profile']")

    # User fields submit under user[]
    assert_html(html, "input[name='user[name]']")
    assert_html(html, "input[name='user[place_name]']")
    assert_html(html, "textarea[name='user[notes]']")
    assert_html(html, "textarea[name='user[mailing_address]']")

    # Upload fields submit under top-level upload[] (not user[upload][])
    assert_html(html, "input[type='file'][name='upload[image]']")
    assert_html(html, "input[name='upload[copyright_holder]']")
    assert_html(html, "select[name='upload[copyright_year]']")
    assert_html(html, "select[name='upload[license_id]']")

    # "Upload photo:" label (no existing image)
    assert_includes(html, "#{:profile_image_create.t}:")
    assert_not_includes(html, "#{:profile_image_change.t}:")

    # Reuse link
    assert_html(html, "a[href='/account/profile/images']")

    # Two submit buttons
    assert_html(html, "input[type='submit']", count: 2)
  end

  # User with a profile image: upload section uses "Upload new photo:" label
  # and copyright fields are pre-filled from the existing image.
  def test_user_with_image
    user = users(:rolf)
    image = user.image
    html = render_form(
      user:,
      copyright_holder: image.copyright_holder,
      copyright_year: image.when.year,
      upload_license_id: image.license_id
    )

    assert_includes(html, "#{:profile_image_change.t}:")
    assert_not_includes(html, "#{:profile_image_create.t}:")

    assert_html(html, "input[name='upload[copyright_holder]']" \
                      "[value='#{image.copyright_holder}']")
    assert_html(html,
                "select[name='upload[copyright_year]'] " \
                "option[value='#{image.when.year}'][selected]")
  end

  # Location field is pre-populated from the user's saved location.
  def test_location_prefill
    user = users(:rolf)
    user.location = locations(:burbank)
    user.place_name ||= user.location&.display_name
    html = render_form(user:)

    assert_html(html, "input[name='user[place_name]']" \
                      "[value='#{user.location.display_name}']")
  end

  private

  def render_form(user:, copyright_holder: "Test User",
                  copyright_year: Time.zone.now.year,
                  upload_license_id: @license.id)
    render(Components::AccountProfileForm.new(
             user,
             copyright_holder:,
             copyright_year:,
             licenses: @licenses,
             upload_license_id:
           ))
  end
end
