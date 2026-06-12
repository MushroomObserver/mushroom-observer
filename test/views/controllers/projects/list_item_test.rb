# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  class ListItemTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_project
      User.current = @user
      project = projects(:eol_project)
      html = render(ListItem.new(project: project))

      # No `.list-group-item` wrapper — supplied by the caller.
      assert_no_html(html, "div.list-group-item")

      # Title link
      assert_html(html, "a[href*='projects/#{project.id}']")
      assert_html(html, "span.h4")

      # Meta row with user
      assert_includes(html, project.created_at.web_time)
    end

    def test_open_membership_badge
      User.current = @user
      project = projects(:eol_project)
      project.open_membership = true
      html = render(ListItem.new(project: project))

      assert_html(html, "span.ml-4")
      assert_includes(html, :OPEN.t)
    end

    def test_closed_membership_no_badge
      User.current = @user
      project = projects(:eol_project)
      project.open_membership = false
      html = render(ListItem.new(project: project))

      assert_no_html(html, "span.ml-4")
    end
  end
end
