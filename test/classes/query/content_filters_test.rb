# frozen_string_literal: true

require("test_helper")

# tests of ContentFilter class to be included in QueryTest
module Query::ContentFiltersTest
  def test_filtering_content_with_images
    expects = Observation.where.not(thumb_image_id: nil).index_order.uniq
    assert_query(expects, :Observation, with_images: "yes")

    expects = Observation.where(thumb_image_id: nil).index_order.uniq
    assert_query(expects, :Observation, with_images: "no")
  end

  def test_filtering_content_with_specimen
    expects = Observation.where(specimen: true).index_order.uniq
    assert_query(expects, :Observation, with_specimen: "yes")

    expects = Observation.where(specimen: false).index_order.uniq
    assert_query(expects, :Observation, with_specimen: "no")
  end

  def test_filtering_content_with_lichen
    expects_obs = Observation.where(Observation[:lifeform].matches("%lichen%")).
                  index_order.uniq
    expects_names = Name.with_correct_spelling.
                    where(Name[:lifeform].matches("%lichen%")).index_order.uniq
    assert_query(expects_obs, :Observation, lichen: "yes")
    assert_query(expects_names, :Name, lichen: "yes")
  end

  def test_filtering_content_with_non_lichen
    expects_obs = Observation.
                  where(Observation[:lifeform].does_not_match("% lichen %")).
                  index_order.uniq
    expects_names = Name.with_correct_spelling.
                    where(Name[:lifeform].does_not_match("% lichen %")).
                    index_order.uniq
    assert_query(expects_obs, :Observation, lichen: "no")
    assert_query(expects_names, :Name, lichen: "no")
  end

  def test_filtering_content_region
    expects = Location.where(Location[:name].matches("%California%")).
              index_order.uniq
    assert_query(expects, :Location, region: "California, USA")
    assert_query(expects, :Location, region: "USA, California")

    expects = Observation.index_order.
              where(Observation[:where].matches("%California, USA")).uniq
    assert_query(expects, :Observation, region: "California, USA")

    expects = Location.where(Location[:name].matches("%, USA").
              or(Location[:name].matches("%, Canada"))).index_order.uniq
    assert(expects.include?(locations(:albion))) # usa
    assert(expects.include?(locations(:elgin_co))) # canada
    assert_query(expects, :Location, region: "North America")
  end

  def test_filtering_content_clade
    names = Name.reorder(id: :asc).
            with_correct_spelling.where(text_name: "Agaricales").or(
              Name.reorder(id: :asc).where(
                Name[:classification].matches_regexp("Order: _Agaricales_")
              )
            ).reorder(sort_name: :asc, id: :desc).distinct
    obs = Observation.reorder(id: :asc).where(text_name: "Agaricales").or(
      Observation.reorder(id: :asc).where(
        Observation[:classification].matches_regexp("Order: _Agaricales_")
      )
    ).reorder(when: :desc, id: :desc).distinct
    assert_query(obs, :Observation, clade: "Agaricales")
    assert_query(names, :Name, clade: "Agaricales")
  end
end
