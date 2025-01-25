# frozen_string_literal: true

require("test_helper")

# tests of Query::FieldSlips class to be included in QueryTest
module Query::FieldSlipsTest
  def test_field_slip_all
    expects = FieldSlip.index_order
    assert_query(expects, :FieldSlip)
  end

  def test_field_slip_by_user
    expects = FieldSlip.index_order.by_user(mary)
    assert_query(expects, :FieldSlip, by_user: mary)
  end

  def test_field_slip_for_project
    expects = FieldSlip.index_order.where(project: projects(:eol_project))
    assert_query(expects, :FieldSlip, project: projects(:eol_project))
  end
end
