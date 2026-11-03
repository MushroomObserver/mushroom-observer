# frozen_string_literal: true

require("test_helper")

class Components::ListGroup::SearchTest < ComponentTestCase
  def test_renders_hidden_fields_and_panel
    project = projects(:bolete_project)
    html = render_search(object: project, project: project)

    assert_html(html, "#list_search .panel-heading",
                text: :list_search_heading.l)
    assert_html(html, "#list_search .panel-body")
    assert_html(
      html, "form#list_search_form[action='#{routes.add_dispatch_path}']"
    )
    assert_html(html, "input[type='hidden'][name='object_id']" \
                      "[value='#{project.id}']")
    assert_html(html, "input[type='hidden'][name='object_type']" \
                      "[value='Project']")
    assert_html(html, "input[type='hidden'][name='project']" \
                      "[value='#{project.id}']")
  end

  def test_status_light_shares_the_label_row_with_the_name_field
    project = projects(:bolete_project)
    html = render_search(object: project, project: project)

    assert_html(html, "label[for='name']", text: :search_status_label.ti)
    # has-id-indicator, then the status light -- both inside the
    # same label row as the "name" field's <label>.
    assert_html(
      html,
      "label[for='name'] ~ .has-id-indicator ~ " \
      "[data-search-status-target='light']"
    )
    assert_html(html, "[data-search-status-target='message']",
                text: :search_status_all_names.l)
  end

  def test_field_slip_quick_add_input
    project = projects(:bolete_project)
    html = render_search(object: project, project: project)

    assert_html(html, "input[name='field_slip']")
    assert_html(html, "button[type='submit']", text: "Add")
  end

  private

  def render_search(object:, object_names: [], project: nil)
    render(Components::ListGroup::Search.new(
             object: object, object_names: object_names, project: project
           ))
  end
end
