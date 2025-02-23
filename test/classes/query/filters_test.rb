# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Filter class
class Query::FiltersTest < UnitTestCase
  include QueryExtensions

  def test_filters
    assert_equal([:with_images, :with_specimen, :lichen, :region, :clade],
                 Query::Filter.all.map(&:sym))
    assert_equal([:region],
                 Query::Filter.by_model(Location).map(&:sym))
    assert_equal([:lichen, :clade],
                 Query::Filter.by_model(Name).map(&:sym))
  end

  def test_find
    fltr = Query::Filter.find(:with_images)
    assert_not_nil(fltr)
    assert_equal(:with_images, fltr.sym)
  end

  def test_filtering_content_with_images
    expects = Observation.with_images.index_order.uniq
    assert_query(expects, :Observation, with_images: "yes")

    expects = Observation.without_images.index_order.uniq
    assert_query(expects, :Observation, with_images: "no")
  end

  def test_filtering_content_with_specimen
    expects = Observation.with_specimen.index_order.uniq
    assert_query(expects, :Observation, with_specimen: "yes")

    expects = Observation.without_specimen.index_order.uniq
    assert_query(expects, :Observation, with_specimen: "no")
  end

  def test_filtering_content_with_lichen
    expects_obs = Observation.of_lichens.index_order.uniq
    assert_query(expects_obs, :Observation, lichen: "yes")
    expects_names = Name.with_correct_spelling.of_lichens.index_order.uniq
    assert_query(expects_names, :Name, lichen: "yes")
  end

  def test_filtering_content_with_non_lichen
    expects_obs = Observation.not_lichens.index_order.uniq
    assert_query(expects_obs, :Observation, lichen: "no")
    expects_names = Name.with_correct_spelling.not_lichens.index_order.uniq
    assert_query(expects_names, :Name, lichen: "no")
  end

  def test_filtering_content_region
    expects = Location.in_region("California, USA").index_order.uniq
    assert_query(expects, :Location, region: "California, USA")
    assert_query(expects, :Location, region: "USA, California")

    expects = Observation.in_region("California, USA").index_order.uniq
    assert_query(expects, :Observation, region: "California, USA")

    expects = Location.in_region("North America").index_order.uniq
    assert(expects.include?(locations(:albion))) # usa
    assert(expects.include?(locations(:elgin_co))) # canada
    assert_query(expects, :Location, region: "North America")
  end

  def test_filtering_content_clade
    names = Name.in_clade("Agaricales").index_order.distinct
    assert_query(names, :Name, clade: "Agaricales")
    obs = Observation.in_clade("Agaricales").index_order.distinct
    assert_query(obs, :Observation, clade: "Agaricales")
  end

  def test_filtering_content_with_subquery
    expects_names = Name.joins(:observations).
                    merge(Observation.with_specimen).index_order.uniq
    assert_query(expects_names,
                 :Name, observation_query: { with_specimen: "yes" })
  end
end
