# frozen_string_literal: true

require "test_helper"

class DescriptionModLinksTest < ComponentTestCase
  def test_renders_nothing_for_anonymous_viewer
    desc = name_descriptions(:peltigera_user_desc)

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: nil
                  )).strip

    # No user → no writer → no admin → Clone is the only icon that
    # always shows (state-agnostic), so the strip renders just the
    # Clone icon (no edit, no destroy, no admin moves).
    assert_html(html, ".icon-link.clone_name_description_link")
    assert_no_html(html, ".edit_name_description_link_#{desc.id}")
    assert_no_html(html, ".move_this_description_name_description_link")
  end

  def test_renders_edit_for_writer
    desc = name_descriptions(:peltigera_user_desc)

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: desc.user
                  ))

    assert_html(html, ".edit_name_description_link_#{desc.id}")
  end

  def test_renders_admin_icons_for_admin
    desc = name_descriptions(:peltigera_user_desc)
    admin = users(:rolf)
    stub_admin_mode!

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: admin
                  ))

    # Admin-only icons (Move, Merge, AdjustPermissions for name desc)
    assert_html(html, ".move_this_description_name_description_link")
    assert_html(html, ".merge_with_another_name_description_link")
    assert_html(html, ".adjust_permissions_name_description_link")
  end

  def test_omits_adjust_permissions_for_location_description
    desc = location_descriptions(:albion_desc)
    stub_admin_mode!

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: users(:rolf)
                  ))

    assert_no_html(html,
                   ".adjust_permissions_location_description_link")
  end

  # Publish icon's auto-generated CSS class is `publish_link` (from
  # the tab's title `:show_description_publish.t` → "Publish").
  def test_renders_publish_for_admin_of_draft_name_description
    desc = name_descriptions(:draft_coprinus_comatus)
    skip("Need a non-public draft for this test") if
      desc.source_type == :public
    stub_admin_mode!

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: users(:rolf)
                  ))

    assert_html(html,
                "a[href='#{routes.publish_name_description_path(desc.id)}']")
  end

  def test_renders_project_link_for_project_sourced_description
    desc = name_descriptions(:draft_coprinus_comatus)
    skip("Need a project-sourced description") if
      desc.source_type != "project" || desc.source_object.nil?

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: users(:rolf)
                  ))

    # Project icon points at the project's show page.
    assert_html(html,
                "a[href='#{routes.project_path(desc.source_object.id)}']")
  end

  def test_renders_make_default_for_public_non_default
    # `make_default_icon` fires when the desc is public AND not
    # already the parent's default description.
    desc = name_descriptions(:peltigera_alt_desc)
    skip("Need a public, non-default name desc") unless
      desc.public && desc.parent.description_id != desc.id

    html = render(Components::DescriptionModLinks.new(
                    description: desc, user: users(:rolf)
                  ))

    assert_html(
      html,
      "a[href='#{routes.make_default_name_description_path(desc.id)}']"
    )
  end
end
