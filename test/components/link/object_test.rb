# frozen_string_literal: true

require("test_helper")

# Tests for Components::Link::Object (app/components/link/object.rb),
# the new model-targeted link class that replaces Link::Object::Base.
class Components::Link::ObjectTest < ComponentTestCase
  def setup
    super
    @project = projects(:bolete_project)
  end

  def test_renders_anchor_to_object_show_page
    html = render(Components::Link::Object.new(object: @project))

    assert_html(html, "a[href='#{routes.project_path(@project)}']",
                text: @project.title)
    assert_html(html, "a.project_link_#{@project.id}")
  end

  def test_name_override_replaces_default_label
    html = render(Components::Link::Object.new(object: @project, name: "BP"))

    assert_html(html, "a.project_link_#{@project.id}", text: "BP")
  end

  def test_nil_object_renders_nothing
    assert_equal("", render(Components::Link::Object.new(object: nil)))
  end

  def test_button_styling_added_alongside_identifier_class
    html = render(Components::Link::Object.new(object: @project,
                                               button: :btn_link))

    assert_html(html, "a.btn.btn-link.project_link_#{@project.id}")
  end
end
