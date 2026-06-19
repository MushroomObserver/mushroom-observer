# frozen_string_literal: true

require("test_helper")

class ObjectLinkTest < ComponentTestCase
  def test_renders_anchor_to_object_show_page
    project = projects(:bolete_project)
    html = render(Components::Link::Object::Base.new(object: project))

    # Behavior pinned: where it links + the selector class + the
    # default visible text comes from `object.title.t`.
    assert_html(html, "a[href='#{routes.project_path(project)}']",
                text: project.title)
    assert_html(html, "a.project_link_#{project.id}")
  end

  def test_name_override_replaces_default_label
    project = projects(:bolete_project)
    html = render(Components::Link::Object::Base.new(object: project,
                                                     name: "BP"))

    assert_html(html, "a.project_link_#{project.id}", text: "BP")
  end

  def test_nil_object_renders_nothing
    assert_equal("", render(Components::Link::Object::Base.new(object: nil)))
  end
end
