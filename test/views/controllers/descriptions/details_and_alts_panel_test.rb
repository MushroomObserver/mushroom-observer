# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::DetailsAndAltsPanelTest <
  ComponentTestCase
  PARTIAL = "descriptions/description_details_and_alts_panel"

  def setup
    super
    # `ComponentTestCase` uses `ActionView::TestCase::TestController`,
    # which doesn't inherit `ApplicationController`'s
    # `append_view_path Rails.root.join("app/views/controllers")`.
    # Some integration paths still render the old ERB partial, so
    # prepend the controllers view path for those code paths to find
    # their templates. NOTE: NO MORE ERB, delete?
    controller.prepend_view_path(
      Rails.root.join("app/views/controllers")
    )
  end

  # -- contract tests --------------------------------------------

  def test_renders_panel_id
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    assert_html(html, "#description_details_and_alts")
  end

  def test_renders_panel_heading
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    assert_html(html, "#description_details_and_alts .panel-heading")
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

    # Left column has a link to the parent's show page.
    assert_html(html, "a[href='#{parent.show_link_args[:controller]}/" \
                      "#{parent.id}']") ||
      assert_html(html, "a[href*='#{parent.id}']")
  end

  def test_renders_change_links_for_writer
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc, user: desc.user))

    # `DescriptionModLinks` renders an icon-link with the edit class
    # when the viewer can write.
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

  def test_renders_alt_descriptions_via_list_view
    desc = name_descriptions(:coprinus_comatus_desc)
    other = name_descriptions(:draft_coprinus_comatus)

    html = render(new_panel(description: desc))

    # The right column embeds `Views::Controllers::Descriptions::List`,
    # which emits `description_link_<id>` for visible non-current descs.
    assert_html(html, "a.description_link_#{other.id}")
  end

  def test_does_not_link_current_description_in_alts
    desc = name_descriptions(:coprinus_comatus_desc)

    html = render(new_panel(description: desc))

    # The current description's title is plain text in the alts
    # list (no self-link).
    assert_no_html(html, "a.description_link_#{desc.id}")
  end

  def test_renders_project_drafts_block_when_projects_present
    desc = name_descriptions(:peltigera_user_desc)
    projects = [projects(:eol_project)]

    html = render(new_panel(description: desc, projects: projects))

    # "Create New Draft For:" block points at the project-scoped
    # new-description path (`?project=<id>&source=project&…`).
    assert_html(html, "a[href*='project=#{projects.first.id}']")
  end

  def test_omits_project_drafts_block_when_projects_blank
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc, projects: nil))

    assert_no_html(html, "a[href*='project=']")
  end

  def test_renders_review_ui_for_name_description_reviewer
    desc = name_descriptions(:peltigera_user_desc)
    reviewer = users(:rolf) # rolf is a reviewer in fixtures
    stub_reviewer!

    html = render(new_panel(description: desc, user: reviewer, review: true))

    # `reviewers-only` block carries the unvetted/vetted/inaccurate
    # `CrudButton::Put` row.
    assert_html(html, ".panel-footer .reviewers-only")
  end

  def test_omits_review_ui_for_location_description
    desc = location_descriptions(:albion_desc)
    stub_reviewer!

    html = render(new_panel(description: desc, review: true))

    # Location descriptions don't have a review-status workflow.
    assert_no_html(html, ".reviewers-only")
  end

  def test_renders_previous_version_link_when_versions_available
    desc = name_descriptions(:peltigera_user_desc)
    skip("Need a description with multiple versions") unless
      desc.versions.size > 1

    html = render(new_panel(description: desc))

    assert_html(html, "a.previous_version_link")
  end

  private

  def new_panel(description:, user: users(:rolf), versions: nil,
                projects: nil, review: false)
    Views::Controllers::Descriptions::DetailsAndAltsPanel.new(
      description: description, user: user,
      versions: versions || description.versions.to_a,
      projects: projects, review: review
    )
  end

  def stub_reviewer!
    controller.define_singleton_method(:reviewer?) { true }
  end
end
