# frozen_string_literal: true

require("test_helper")

# test the helpers for HerbariaController
class HerbariaHelperTest < ActionView::TestCase
  def test_herbarium_top_users
    # This herbarium has two curators: rolf and roy
    # But only rolf has used it
    nybg_h_top_users = herbarium_top_users(herbaria(:nybg_herbarium).id)
    assert_equal(1, nybg_h_top_users.count)
    assert_equal("rolf", nybg_h_top_users[0].login)

    # Dick has not used his herbarium
    dick_h_top_users = herbarium_top_users(herbaria(:dick_herbarium).id)
    assert_equal(0, dick_h_top_users.count)

    # Mary's the top user of fundis herbarium
    fundis_h_top_users = herbarium_top_users(herbaria(:fundis_herbarium).id)
    assert_equal(1, fundis_h_top_users.count)
    assert_equal("mary", fundis_h_top_users[0].login)
    # Now move all rolf's records to this herbarium
    HerbariumRecord.where(user_id: users(:rolf).id).
      update_all(herbarium_id: herbaria(:fundis_herbarium).id)
    fundis_h_top_users = herbarium_top_users(herbaria(:fundis_herbarium).id)
    assert_equal(2, fundis_h_top_users.count)
    assert_equal("rolf", fundis_h_top_users[0].login)
    assert_equal("mary", fundis_h_top_users[1].login)

    # Thorsten's the top user of fundis herbarium
    field_h_top_users = herbarium_top_users(herbaria(:field_museum).id)
    assert_equal(1, field_h_top_users.count)
    assert_equal("thorsten", field_h_top_users[0].login)
    # Now change the attribution of thorsten's herbarium record
    HerbariumRecord.find(herbarium_records(:field_museum_record).id).
      update(user_id: users(:katrina).id)
    field_h_top_users = herbarium_top_users(herbaria(:field_museum).id)
    assert_equal(1, field_h_top_users.count)
    assert_equal("katrina", field_h_top_users[0].login)
  end
end
