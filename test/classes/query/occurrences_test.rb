# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Occurrences class to be included in QueryTest
class Query::OccurrencesTest < UnitTestCase
  include QueryExtensions

  def test_occurrence_by_user_alias
    occ = occurrences(:occ_field_slip_one)
    scope = Occurrence.by_users(occ.user).order_by(:created_at)
    assert_query(scope, :Occurrence, by_user: occ.user.id)
  end

  def test_occurrence_observation_alias
    occ = occurrences(:occ_field_slip_one)
    scope = Occurrence.observations(occ.primary_observation.id).
            order_by(:created_at)
    assert_query(scope, :Occurrence,
                 observation: occ.primary_observation.id)
  end

  def test_occurrence_field_slip_alias
    occ = occurrences(:occ_field_slip_one)
    scope = Occurrence.field_slips(occ.field_slip.id).order_by(:created_at)
    assert_query(scope, :Occurrence, field_slip: occ.field_slip.id)
  end
end
