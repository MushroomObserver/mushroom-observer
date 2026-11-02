# frozen_string_literal: true

require "test_helper"

class AutocompleteForUserProjectTest < UnitTestCase
  def test_rough_matches_includes_member_project
    rolf = users(:rolf)
    auto = Autocomplete::ForUserProject.new(string: "EOL", user_id: rolf.id)

    names = auto.rough_matches("E").pluck(:name)

    assert_includes(names, projects(:eol_project).title)
  end

  def test_rough_matches_excludes_non_member_project
    rolf = users(:rolf)
    auto = Autocomplete::ForUserProject.new(string: "Bolete", user_id: rolf.id)

    names = auto.rough_matches("B").pluck(:name)

    assert_not_includes(names, projects(:bolete_project).title)
  end

  def test_exact_match_includes_member_project
    rolf = users(:rolf)
    project = projects(:eol_project)
    auto = Autocomplete::ForUserProject.new(
      string: project.title, user_id: rolf.id
    )

    assert_equal([project.title], auto.exact_match(project.title).pluck(:name))
  end

  def test_exact_match_excludes_non_member_project
    rolf = users(:rolf)
    project = projects(:bolete_project)
    auto = Autocomplete::ForUserProject.new(
      string: project.title, user_id: rolf.id
    )

    assert_equal([], auto.exact_match(project.title))
  end

  def test_blank_user_id_yields_no_matches
    auto = Autocomplete::ForUserProject.new(string: "EOL", user_id: nil)

    assert_equal([], auto.rough_matches("E"))
  end
end
