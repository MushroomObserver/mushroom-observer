# frozen_string_literal: true

require("test_helper")

class Tab::Project::AliasEditTest < UnitTestCase
  include Rails.application.routes.url_helpers

  def test_alias_edit
    alias_ = project_aliases(:one)
    tab = Tab::Project::AliasEdit.new(
      project_id: alias_.project_id, name: "Edit Project Alias RS",
      id: alias_.id
    )

    assert_equal("Edit Project Alias RS", tab.title)
    assert_equal(
      edit_project_alias_path(project_id: alias_.project_id, id: alias_.id),
      tab.path
    )
    assert_equal(:edit.ti, tab.alt_title)
    assert_equal({ icon: :edit }, tab.html_options)
    assert_equal(alias_.id, tab.model.id)
  end
end
