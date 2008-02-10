# Nathan and I have decided to disable this for now. (JPH -20080221)
# require File.dirname(__FILE__) + '/../test_helper'
# 
# class PreferredNamingTest < Test::Unit::TestCase
#   fixtures :observations
#   fixtures :users
#   fixtures :namings
#   fixtures :preferred_namings
# 
#   # Create one.
#   def test_create
#     assert_kind_of Naming, @agaricus_campestris_naming
#     assert_kind_of Observation, @agaricus_campestris_obs
#     assert_kind_of User, @mary
#     pn = PreferredNaming.new(
#         :naming      => @agaricus_campestris_naming,
#         :observation => @agaricus_campestris_obs,
#         :user        => @mary
#     )
#     assert pn.save, pn.errors.full_messages.join("; ")
#   end
# 
#   # Change an existing one.
#   def test_update
#     assert_kind_of Naming, @coprinus_comatus_naming
#     assert_kind_of Naming, @agaricus_campestris_naming
#     assert_kind_of Observation, @coprinus_comatus_obs
#     assert_kind_of User, @mary
#     assert_kind_of PreferredNaming, @marys_cc_pn
#     assert_equal @coprinus_comatus_other_naming, @marys_cc_pn.naming
#     @marys_cc_pn.naming = @coprinus_comatus_naming
#     assert @marys_cc_pn.save, @marys_cc_pn.errors.full_messages.join("; ")
#     @marys_cc_pn.reload
#     assert_equal @coprinus_comatus_naming, @marys_cc_pn.naming
#   end
# 
#   # Make sure it fails if we screw up.
#   def test_validate
#     pn = PreferredNaming.new()
#     assert !pn.save
#     assert_equal 3, pn.errors.count
#     assert_equal "can't be blank", pn.errors.on(:naming)
#     assert_equal "can't be blank", pn.errors.on(:observation)
#     assert_equal "can't be blank", pn.errors.on(:user)
#   end
# 
#   # Destroy one.
#   def test_destroy
#     id = @marys_cc_pn.id
#     @marys_cc_pn.destroy
#     assert_raise(ActiveRecord::RecordNotFound) { PreferredNaming.find(id) }
#   end
# end
