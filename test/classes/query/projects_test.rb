# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Projects class to be included in QueryTest
class Query::ProjectsTest < UnitTestCase
  include QueryExtensions

  def test_project_all
    expects = Project.index_order
    assert_query(expects, :Project)
  end

  def test_project_by_rss_log
    expects = Project.order_by_rss_log
    assert_query(expects, :Project, by: :rss_log)
  end

  def test_project_in_set
    assert_query([projects(:eol_project).id],
                 :Project, ids: [projects(:eol_project).id])
    assert_query([], :Project, ids: [])
  end

  def test_project_members
    assert_query(Project.index_order.with_members(rolf),
                 :Project, members: [rolf])
    assert_query([], :Project, members: [])
  end

  def test_project_pattern_search
    assert_query([],
                 :Project, pattern: "no project has this")
    # title
    expects = project_pattern_search("bolete")
    assert_query(expects, :Project, pattern: "bolete")
    # summary
    expects = project_pattern_search("two lists")
    assert_query(expects, :Project, pattern: "two lists")

    expects = Project.index_order
    assert_query(expects, :Project, pattern: "")
  end

  def project_pattern_search(pattern)
    Project.where(Project[:title].matches("%#{pattern}%").
                  or(Project[:summary].matches("%#{pattern}%"))).
      index_order.distinct
  end
end
