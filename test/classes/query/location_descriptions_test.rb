# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::LocationDescriptions class to be included in QueryTest
class Query::LocationDescriptionsTest < UnitTestCase
  include QueryExtensions

  def test_location_description_all
    gualala = locations(:gualala)
    all_descs = LocationDescription.all.to_a
    all_gualala_descs = LocationDescription.
                        where(location: gualala).to_a
    public_gualala_descs = LocationDescription.
                           where(location: gualala, public: true).to_a
    assert(all_gualala_descs.length < all_descs.length)
    assert(public_gualala_descs.length < all_gualala_descs.length)

    assert_query(all_descs, :LocationDescription, by: :id)
    assert_query(all_gualala_descs, :LocationDescription,
                 by: :id, locations: gualala)
    assert_query(public_gualala_descs, :LocationDescription,
                 by: :id, locations: gualala, public: "yes")
  end

  def test_location_description_by_user
    expects = LocationDescription.where(user: rolf).to_a
    assert_query(expects, :LocationDescription, by_user: rolf)

    expects = LocationDescription.where(user: mary).to_a
    assert_equal(0, expects.length)
    assert_query(expects, :LocationDescription, by_user: mary)
  end

  def test_location_description_by_author
    loc1, loc2, loc3 = Location.all.index_order
    desc1 =
      loc1.description ||= LocationDescription.create!(location_id: loc1.id)
    desc2 =
      loc2.description ||= LocationDescription.create!(location_id: loc2.id)
    desc3 =
      loc3.description ||= LocationDescription.create!(location_id: loc3.id)
    desc1.add_author(rolf)
    desc2.add_author(mary)
    desc3.add_author(rolf)

    # Using Rails instead of db; don't know how to do it with .joins & .where
    descs = LocationDescription.all
    assert_query(descs.find_all { |d| d.authors.include?(rolf) },
                 :LocationDescription, by_author: rolf, by: :id)
    assert_query(descs.find_all { |d| d.authors.include?(mary) },
                 :LocationDescription, by_author: mary)
    assert_query([], :LocationDescription, by_author: users(:zero_user))
  end

  def test_location_description_by_editor
    loc1, loc2, loc3 = Location.index_order
    desc1 =
      loc1.description ||= LocationDescription.create!(location_id: loc1.id)
    desc2 =
      loc2.description ||= LocationDescription.create!(location_id: loc2.id)
    desc3 =
      loc3.description ||= LocationDescription.create!(location_id: loc3.id)
    desc1.add_editor(rolf) # Fails since he's already an author!
    desc2.add_editor(mary)
    desc3.add_editor(rolf)

    # Using Rails instead of db; don't know how to do it with .joins & .where
    descs = LocationDescription.all
    assert_query(descs.find_all { |d| d.editors.include?(rolf) },
                 :LocationDescription, by_editor: rolf, by: :id)
    assert_query(descs.find_all { |d| d.editors.include?(mary) },
                 :LocationDescription, by_editor: mary)
    assert_query([], :LocationDescription, by_editor: users(:zero_user))
  end

  def test_location_description_in_set
    assert_query([],
                 :LocationDescription,
                 ids: rolf.id)
    assert_query(LocationDescription.all,
                 :LocationDescription,
                 ids: LocationDescription.select(:id).to_a)
    assert_query([location_descriptions(:albion_desc).id],
                 :LocationDescription,
                 ids: [rolf.id, location_descriptions(:albion_desc).id])
  end

  def test_location_description_coercion
    ds1 = location_descriptions(:albion_desc)
    ds2 = location_descriptions(:no_mushrooms_location_desc)
    description_coercion_assertions(ds1, ds2, :Location)
  end
end
