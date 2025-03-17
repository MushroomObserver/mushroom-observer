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

  def mary_field_slips
    [field_slips(:field_slip_one), field_slips(:field_slip_two),
     field_slips(:field_slip_no_obs)]
  end

  def test_field_slip_by_users
    expects = mary_field_slips
    scope = FieldSlip.by_users(mary).index_order
    assert_query_scope(expects, scope, :FieldSlip, by_users: mary)
  end

  def eol_field_slips
    mary_field_slips + [field_slips(:field_slip_no_trust)]
  end

  def test_field_slip_for_project
    expects = eol_field_slips
    scope = FieldSlip.projects(projects(:eol_project)).index_order
    assert_query_scope(expects, scope,
                       :FieldSlip, projects: projects(:eol_project))
    # test lookup by name
    expects = FieldSlip.projects(projects(:eol_project).title).index_order
    assert_query(expects, :FieldSlip, projects: projects(:eol_project))
  end
end
