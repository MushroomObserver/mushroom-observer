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

  def test_herbarium_by_records
    expects = Herbarium.left_outer_joins(:herbarium_records).group(:id).
              order(HerbariumRecord[:id].count.desc, Herbarium[:id].desc)
    assert_query(expects, :Herbarium, by: :records)
  end

  def test_herbarium_id_in_set
    expects = [
      herbaria(:nybg_herbarium),
      herbaria(:dick_herbarium)
    ]
    scope = Herbarium.id_in_set(expects.pluck(:id))
    assert_query_scope(expects, scope, :Herbarium, id_in_set: expects)
  end

  def test_herbarium_pattern_search
    # [herbaria(:nybg_herbarium)]
    expects = Herbarium.index_order.where(
      Herbarium[:code].concat(Herbarium[:name]).
      concat(Herbarium[:description].coalesce("")).
      concat(Herbarium[:mailing_address].coalesce("")).matches("%awesome%")
    ).distinct

    assert_query(expects, :Herbarium, pattern: "awesome")
  end
end
