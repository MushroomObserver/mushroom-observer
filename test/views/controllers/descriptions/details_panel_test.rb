# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::DetailsPanelTest < ComponentTestCase
  def test_renders_panel_id
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    assert_html(html, "#description_details")
  end

  def test_renders_panel_heading
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    assert_html(html, "#description_details .panel-heading")
  end

  def test_renders_footer_only_when_review_is_true
    desc = name_descriptions(:peltigera_user_desc)

    with_review = render(new_panel(description: desc, review: true))
    without = render(new_panel(description: desc, review: false))

    # The Bootstrap panel-footer slot exists only when `review: true`.
    assert_html(with_review, ".panel-footer")
    assert_no_html(without, ".panel-footer")
  end

  def test_renders_parent_link
    desc = name_descriptions(:peltigera_user_desc)
    parent = desc.parent

    html = render(new_panel(description: desc))

    assert_html(html, "a[href*='#{parent.id}']")
  end

  def test_renders_change_links_for_writer
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc, user: desc.user))

    # `ModLinks` renders an icon-link with the edit class when the
    # viewer can write.
    assert_html(html,
                ".panel-heading-links .edit_name_description_link_#{desc.id}")
  end

  def test_omits_edit_icon_for_anonymous_viewer
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc, user: nil))

    assert_no_html(
      html,
      ".panel-heading-links .edit_name_description_link_#{desc.id}"
    )
  end

  def test_renders_review_ui_for_name_description_reviewer
    desc = name_descriptions(:peltigera_user_desc)
    reviewer = users(:rolf) # rolf is a reviewer in fixtures
    stub_reviewer!

    html = render(new_panel(description: desc, user: reviewer, review: true))

    # `reviewers-only` block carries the unvetted/vetted/inaccurate
    # `Button::Put` row.
    assert_html(html, ".panel-footer .reviewers-only")
  end

  def test_omits_review_ui_for_location_description
    desc = location_descriptions(:albion_desc)
    stub_reviewer!

    html = render(new_panel(description: desc, review: true))

    # Location descriptions don't have a review-status workflow.
    assert_no_html(html, ".reviewers-only")
  end

  private

  def new_panel(description:, user: users(:rolf), review: false)
    Views::Controllers::Descriptions::DetailsPanel.new(
      description: description, user: user, review: review
    )
  end

  def stub_reviewer!
    controller.define_singleton_method(:reviewer?) { true }
  end
end
