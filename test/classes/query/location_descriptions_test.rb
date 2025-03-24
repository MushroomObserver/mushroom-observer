# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::LocationDescriptions class to be included in QueryTest
class Query::LocationDescriptionsTest < UnitTestCase
  include QueryExtensions

  def test_location_description_all
    assert_query(LocationDescription.all, :LocationDescription, order_by: :id)
  end

  def test_location_description_locations
    gualala = locations(:gualala)
    all_descs = LocationDescription.all
    all_gualala_descs = LocationDescription.locations(gualala)
    public_gualala_descs = all_gualala_descs.is_public
    assert(all_gualala_descs.length < all_descs.length)
    assert(public_gualala_descs.length < all_gualala_descs.length)

    assert_query(all_gualala_descs,
                 :LocationDescription, order_by: :id, locations: gualala)
    assert_query(public_gualala_descs,
                 :LocationDescription, order_by: :id, locations: gualala,
                                       is_public: "yes")
  end

  def test_location_description_by_user
    expects = LocationDescription.where(user: rolf).to_a
    assert_query(expects, :LocationDescription, by_users: rolf)

    expects = LocationDescription.where(user: mary).to_a
    assert_equal(0, expects.length)
    assert_query(expects, :LocationDescription, by_users: mary)
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

    descs = LocationDescription.all
    assert_query_scope(descs.find_all { |d| d.authors.include?(rolf) },
                       LocationDescription.by_author(rolf),
                       :LocationDescription, by_author: rolf.login,
                                             order_by: :id)
    assert_query_scope(descs.find_all { |d| d.authors.include?(mary) },
                       LocationDescription.by_author(mary),
                       :LocationDescription, by_author: mary.login)
    assert_query_scope([],
                       LocationDescription.by_author(users(:zero_user)),
                       :LocationDescription, by_author: users(:zero_user))
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

    descs = LocationDescription.all
    assert_query_scope(descs.find_all { |d| d.editors.include?(rolf) },
                       LocationDescription.by_editor(rolf),
                       :LocationDescription, by_editor: rolf, order_by: :id)
    assert_query_scope(descs.find_all { |d| d.editors.include?(mary) },
                       LocationDescription.by_editor(mary),
                       :LocationDescription, by_editor: mary)
    assert_query_scope([],
                       LocationDescription.by_editor(users(:zero_user)),
                       :LocationDescription, by_editor: users(:zero_user))
  end

  def test_location_description_in_set
    assert_query(
      [], :LocationDescription, id_in_set: rolf.id
    )
    assert_query(
      LocationDescription.all,
      :LocationDescription, id_in_set: LocationDescription.select(:id).to_a
    )
    assert_query(
      [location_descriptions(:albion_desc).id],
      :LocationDescription, id_in_set: [rolf.id,
                                        location_descriptions(:albion_desc).id]
    )
  end

  def test_location_description_content_has
    expects = [location_descriptions(:albion_desc)]
    scope = LocationDescription.content_has("to play with").index_order
    assert_query_scope(expects, scope,
                       :LocationDescription, content_has: "to play with")
  end
end
