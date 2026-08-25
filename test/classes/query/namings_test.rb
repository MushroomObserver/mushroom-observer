# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Namings class to be included in QueryTest
class Query::NamingsTest < UnitTestCase
  include QueryExtensions

  def test_naming_all
    expects = Naming.order_by_default
    assert_query(expects, :Naming)
  end

  def test_naming_id_in_set
    namings = [namings(:coprinus_comatus_naming),
               namings(:agaricus_campestris_naming)]
    ids = namings.map(&:id)
    scope = Naming.id_in_set(ids).order_by_default
    assert_query_scope(ids, scope, :Naming, id_in_set: ids)
  end

  def test_naming_by_users
    ids = Naming.where(user: dick).order_by_default.pluck(:id)
    scope = Naming.by_users(dick).order_by_default
    assert_query_scope(ids, scope, :Naming, by_users: dick.id)
  end

  def test_naming_observations
    obs = observations(:coprinus_comatus_obs)
    ids = Naming.observations(obs.id).order_by_default.pluck(:id)
    scope = Naming.observations(obs.id).order_by_default
    assert_query_scope(ids, scope, :Naming, observations: [obs.id])
  end

  def test_naming_names
    name = names(:fungi)
    ids = Naming.names(name.id).order_by_default.pluck(:id)
    scope = Naming.names(name.id).order_by_default
    assert_query_scope(ids, scope, :Naming, names: [name.id])
  end

  def test_naming_confidence
    naming = namings(:coprinus_comatus_naming) # vote_cache: 1
    range = naming.vote_cache..naming.vote_cache
    scope = Naming.confidence(range).order_by_default
    assert_query_scope([naming.id], scope, :Naming,
                       confidence: naming.vote_cache.to_s)
  end
end
