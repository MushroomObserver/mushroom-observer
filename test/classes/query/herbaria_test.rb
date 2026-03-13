# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Herbaria class to be included in QueryTest
class Query::HerbariaTest < UnitTestCase
  include QueryExtensions

  def test_herbarium_all
    expects = Herbarium.order_by_default
    assert_query(expects, :Herbarium)
  end

  def test_herbarium_order_by_records
    expects = Herbarium.order_by(:records)
    assert_query(expects, :Herbarium, order_by: :records)
  end

  def test_herbarium_order_by_code
    expects = Herbarium.order_by(:code)
    assert_query(expects, :Herbarium, order_by: :code)
  end

  def test_herbarium_order_by_code_then_name
    expects = Herbarium.order_by(:code_then_name)
    assert_query(expects, :Herbarium, order_by: :code_then_name)
  end

  def test_herbarium_order_by_name
    expects = Herbarium.order_by(:name)
    assert_query(expects, :Herbarium, order_by: :name)
  end

  def test_herbarium_nonpersonal
    expects = Herbarium.nonpersonal.order_by_default
    assert_query(expects, :Herbarium, nonpersonal: true)
    # Currently nonpersonal(false) is not parsed by Query, maybe intentionally.
    # It seems to me this param should be reversed to `personal`, and the
    # default index behavior adjusted, but that requires some focus. - AN 202503
    # expects = Herbarium.nonpersonal(false).order_by_default
    # assert_query(expects.select(:id).distinct, :Herbarium, nonpersonal: false)
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
    expects = [herbaria(:rolf_herbarium), herbaria(:curatorless_herbarium),
               herbaria(:dick_herbarium)]
    scope = Herbarium.name_has("Herbarium").order_by_default
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

  def test_herbarium_by_users
    expects = [herbaria(:rolf_herbarium)]
    scope = Herbarium.by_users(rolf.id)
    assert_query_scope(
      expects, scope, :Herbarium, by_users: rolf.id
    )
  end

  def test_herbarium_pattern_search
    expects = [herbaria(:nybg_herbarium)]
    scope = Herbarium.pattern("awesome")
    assert_query_scope(expects, scope, :Herbarium, pattern: "awesome")
  end
end
