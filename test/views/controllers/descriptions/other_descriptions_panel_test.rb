# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::OtherDescriptionsPanelTest <
  ComponentTestCase
  def test_renders_panel_id
    desc = name_descriptions(:coprinus_comatus_desc)

    html = render(new_panel(description: desc))

    assert_html(html, "#other_descriptions")
  end

  def test_renders_other_descriptions_via_list_view
    desc = name_descriptions(:coprinus_comatus_desc)
    other = name_descriptions(:draft_coprinus_comatus)

    html = render(new_panel(description: desc))

    # Embeds `Views::Controllers::Descriptions::List`, which emits
    # `description_link_<id>` for visible non-current descs.
    assert_html(html, "a.description_link_#{other.id}")
  end

  def test_does_not_link_current_description
    desc = name_descriptions(:coprinus_comatus_desc)

    html = render(new_panel(description: desc))

    # The current description's title is plain text in the list (no
    # self-link).
    assert_no_html(html, "a.description_link_#{desc.id}")
  end

  def test_renders_new_draft_form
    desc = name_descriptions(:peltigera_user_desc)

    html = render(new_panel(description: desc))

    # `Components::Description::NewDraftForm` renders a form
    # targeting the parent name's new-description path.
    assert_html(html,
                "form[action='#{routes.new_name_description_path(
                  name_id: desc.parent.id
                )}']")
  end

  def test_passes_incoming_project_to_new_draft_form
    desc = name_descriptions(:peltigera_user_desc)
    project = projects(:eol_project)

    html = render(new_panel(description: desc, incoming_project: project))

    assert_html(html, "input[name='project'][value='#{project.id}']")
  end

  private

  def new_panel(description:, user: users(:rolf), incoming_project: nil)
    Views::Controllers::Descriptions::OtherDescriptionsPanel.new(
      description: description, user: user,
      incoming_project: incoming_project
    )
  end
end
