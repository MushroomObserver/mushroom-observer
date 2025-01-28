# frozen_string_literal: true

require("test_helper")

# tests of Query::Herbaria class to be included in QueryTest
module Query::HerbariaTest
  def test_herbarium_all
    expects = Herbarium.index_order
    assert_query(expects.select(:id).distinct, :Herbarium)
  end

  def test_herbarium_by_records
    expects = Herbarium.left_outer_joins(:herbarium_records).group(:id).
              # Wrap known safe argument in Arel
              # to prevent "Dangerous query method" Deprecation Warning
              order(HerbariumRecord[:id].count.desc, Herbarium[:id].desc)
    assert_query(expects, :Herbarium, by: :records)
  end

  def test_herbarium_in_set
    expects = [
      herbaria(:dick_herbarium),
      herbaria(:nybg_herbarium)
    ]
    assert_query(expects, :Herbarium, ids: expects)
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
