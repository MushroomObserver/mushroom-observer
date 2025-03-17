# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Herbaria class to be included in QueryTest
class Query::HerbariaTest < UnitTestCase
  include QueryExtensions

  def test_herbarium_all
    expects = Herbarium.index_order
    assert_query(expects.select(:id).distinct, :Herbarium)
  end

  def test_herbarium_nonpersonal
    expects = Herbarium.nonpersonal.index_order
    assert_query(expects.select(:id).distinct, :Herbarium, nonpersonal: true)
    # expects = Herbarium.nonpersonal(false).index_order
    # assert_query(expects.select(:id).distinct, :Herbarium, nonpersonal: false)
  end

  def test_herbarium_by_records
    expects = Herbarium.left_outer_joins(:herbarium_records).group(:id).
              order(HerbariumRecord[:id].count.desc, Herbarium[:id].desc)
    assert_query(expects, :Herbarium, by: :records)
  end

  def test_herbarium_id_in_set
    expects = [herbaria(:nybg_herbarium), herbaria(:dick_herbarium)]
    scope = Herbarium.id_in_set(expects.pluck(:id))
    assert_query_scope(expects, scope, :Herbarium, id_in_set: expects)
  end

  def test_herbarium_code_has
    expects = [herbaria(:field_museum)]
    scope = Herbarium.code_has("F")
    assert_query_scope(expects, scope, :Herbarium, code_has: "F")
  end

  def test_herbarium_name_has
    expects = [herbaria(:curatorless_herbarium), herbaria(:dick_herbarium),
               herbaria(:rolf_herbarium)]
    scope = Herbarium.name_has("Herbarium").index_order
    assert_query_scope(expects, scope, :Herbarium, name_has: "Herbarium")
  end

  def test_herbarium_description_has
    expects = [herbaria(:nybg_herbarium)]
    scope = Herbarium.description_has("awesome")
    assert_query_scope(expects, scope, :Herbarium, description_has: "awesome")
  end

  def test_herbarium_mailing_address_has
    expects = [herbaria(:field_museum)]
    scope = Herbarium.mailing_address_has("Chicago")
    assert_query_scope(
      expects, scope, :Herbarium, mailing_address_has: "Chicago"
    )
  end

  def test_herbarium_pattern_search
    expects = [herbaria(:nybg_herbarium)]
    scope = Herbarium.pattern("awesome").distinct
    assert_query_scope(expects, scope, :Herbarium, pattern: "awesome")
  end
end
