# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::FieldSlips class to be included in QueryTest
class Query::FieldSlipsTest < UnitTestCase
  include QueryExtensions

  def test_field_slip_all
    expects = FieldSlip.index_order
    assert_query(expects, :FieldSlip)
  end

  def test_field_slip_by_user
    expects = FieldSlip.index_order.by_user(mary)
    assert_query(expects, :FieldSlip, by_users: mary)
  end

  def test_field_slip_for_project
    expects = FieldSlip.index_order.where(project: projects(:eol_project))
    assert_query(expects, :FieldSlip, projects: projects(:eol_project))
    # test scope
    expects = FieldSlip.index_order.projects(projects(:eol_project))
    assert_query(expects, :FieldSlip, projects: projects(:eol_project))
    # test lookup by name
    expects = FieldSlip.index_order.projects(projects(:eol_project).title)
    assert_query(expects, :FieldSlip, projects: projects(:eol_project))
  end
end
