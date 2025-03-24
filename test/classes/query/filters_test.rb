# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Filter class
class Query::FiltersTest < UnitTestCase
  include QueryExtensions

  def test_filters
    assert_equal([:has_images, :has_specimen, :lichen, :region, :clade],
                 Query::Filter.all.map(&:sym))
    assert_equal([:region],
                 Query::Filter.by_model(Location).map(&:sym))
    assert_equal([:lichen, :clade],
                 Query::Filter.by_model(Name).map(&:sym))
  end

  def test_find
    fltr = Query::Filter.find(:has_images)
    assert_not_nil(fltr)
    assert_equal(:has_images, fltr.sym)
  end

  def test_filtering_content_has_images
    expects = Observation.has_images.order_by_default.uniq
    assert_query(expects, :Observation, has_images: "yes")

    expects = Observation.has_images(false).order_by_default.uniq
    assert_query(expects, :Observation, has_images: "no")
  end

  def test_filtering_content_has_specimen
    expects = Observation.has_specimen.order_by_default.uniq
    assert_query(expects, :Observation, has_specimen: "yes")

    expects = Observation.has_specimen(false).order_by_default.uniq
    assert_query(expects, :Observation, has_specimen: "no")
  end

  def test_filtering_content_with_lichen
    expects_obs = Observation.lichen(:yes).order_by_default.uniq
    assert_query(expects_obs, :Observation, lichen: "yes")
    expects_names = Name.with_correct_spelling.lichen(:yes).order_by_default.uniq
    assert_query(expects_names, :Name, lichen: "yes")
  end

  def test_filtering_content_with_non_lichen
    expects_obs = Observation.lichen(:no).order_by_default.uniq
    assert_query(expects_obs, :Observation, lichen: "no")
    expects_names = Name.with_correct_spelling.lichen(:no).order_by_default.uniq
    assert_query(expects_names, :Name, lichen: "no")
  end

  def test_filtering_content_region
    expects = Location.region("California, USA").order_by_default.uniq
    assert_query(expects, :Location, region: "California, USA")
    assert_query(expects, :Location, region: "USA, California")

    expects = Observation.region("California, USA").order_by_default.uniq
    assert_query(expects, :Observation, region: "California, USA")

    expects = Location.region("North America").order_by_default.uniq
    assert(expects.include?(locations(:albion))) # usa
    assert(expects.include?(locations(:elgin_co))) # canada
    assert_query(expects, :Location, region: "North America")
  end

  def test_filtering_content_clade
    names = Name.clade("Agaricales").order_by_default.distinct
    assert_query(names, :Name, clade: "Agaricales")
    obs = Observation.clade("Agaricales").order_by_default.distinct
    assert_query(obs, :Observation, clade: "Agaricales")
  end

  def test_filtering_content_with_subquery
    expects_names = Name.joins(:observations).
                    merge(Observation.has_specimen).order_by_default.uniq
    assert_query(expects_names,
                 :Name, observation_query: { has_specimen: "yes" })
  end
end
