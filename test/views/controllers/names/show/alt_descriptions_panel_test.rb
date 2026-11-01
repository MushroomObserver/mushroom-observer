# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Names::Show::AltDescriptionsPanelTest <
  ComponentTestCase
  def test_renders_panel_id
    html = render(new_panel)

    assert_html(html, "#name_descriptions")
  end

  def test_renders_heading_link_when_logged_in
    html = render(new_panel(user: users(:rolf)))

    assert_html(
      html,
      "#name_descriptions .panel-heading-links a[href='" \
      "#{routes.new_name_description_path(name_id: names(:peltigera).id)}']"
    )
  end

  def test_omits_heading_link_when_logged_out
    html = render(new_panel(user: nil))

    assert_no_html(html, "#name_descriptions .panel-heading-links")
  end

  def test_renders_descriptions_list
    html = render(new_panel)

    # Embeds `Views::Controllers::Descriptions::List`, which emits
    # `description_link_<id>` for visible descriptions.
    assert_html(
      html, "a.description_link_#{name_descriptions(:peltigera_alt_desc).id}"
    )
  end

  private

  def new_panel(name: names(:peltigera), user: users(:rolf))
    Views::Controllers::Names::Show::AltDescriptionsPanel.new(
      name: name, user: user
    )
  end
end
