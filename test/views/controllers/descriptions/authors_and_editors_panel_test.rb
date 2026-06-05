# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::AuthorsAndEditorsPanelTest <
  ComponentTestCase
  def test_renders_authors_and_editors_block
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    # Wraps `Components::AuthorsAndEditors` in `.text-center`.
    assert_html(html, ".text-center")
  end

  def test_renders_license_badge_when_license_present
    desc = name_descriptions(:peltigera_user_desc)
    skip("Need a description with a license") if desc.license.nil?

    html = render(new_panel(description: desc))

    assert_html(html, "#license")
  end

  def test_omits_license_badge_when_no_license
    desc = name_descriptions(:peltigera_user_desc)
    desc.update_column(:license_id, nil)

    html = render(new_panel(description: desc))

    assert_no_html(html, "#license")
  end

  def test_default_versions_is_empty_array
    desc = name_descriptions(:peltigera_user_desc)

    html = render(
      Views::Controllers::Descriptions::AuthorsAndEditorsPanel.new(
        description: desc, user: users(:rolf)
      )
    )

    # Renders successfully without a `versions:` arg.
    assert_html(html, ".text-center")
  end

  private

  def new_panel(description:, user: users(:rolf))
    Views::Controllers::Descriptions::AuthorsAndEditorsPanel.new(
      description: description, user: user,
      versions: description.versions.to_a
    )
  end
end
