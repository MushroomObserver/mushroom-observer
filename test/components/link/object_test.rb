# frozen_string_literal: true

require("test_helper")

class ObjectLinkTest < ComponentTestCase
  def test_renders_anchor_to_object_show_page
    project = projects(:bolete_project)
    html = render_object(object: project)

    # Behavior pinned: where it links + the selector class + the
    # default visible text comes from `object.title.t`.
    assert_html(html, "a[href='#{routes.project_path(project)}']",
                text: project.title)
    assert_html(html, "a.project_link_#{project.id}")
  end

  def test_name_override_replaces_default_label
    project = projects(:bolete_project)
    html = render_object(object: project, name: "BP")

    assert_html(html, "a.project_link_#{project.id}", text: "BP")
  end

  def test_nil_object_renders_nothing
    assert_equal("", render_object(object: nil))
  end

  def test_pass_through_attributes_merge_with_identifier_class
    project = projects(:bolete_project)
    html = render_object(object: project, id: "custom_id",
                         data: { tooltip_target: "tip" })

    assert_html(html, "a.project_link_#{project.id}#custom_id" \
                       "[data-tooltip-target='tip']")
  end

  def test_block_content_overrides_default_label
    project = projects(:bolete_project)
    html = render(Components::Link::Object.new(object: project)) do
      view_context.tag.span("Custom", class: "custom-content")
    end

    assert_html(html, "a.project_link_#{project.id} .custom-content",
                text: "Custom")
  end

  private

  def render_object(**)
    render(Components::Link::Object.new(**))
  end
end
