# frozen_string_literal: true

require "test_helper"

class DescriptionTest < UnitTestCase
  # Make sure authors and editors are as they should be.
  def assert_authors_and_editors(obj, authors, editors, msg)
    assert_equal(authors.sort, obj.authors.map(&:login).sort,
                 "Authors wrong: #{msg}")
    assert_equal(editors.sort, obj.editors.map(&:login).sort,
                 "Editors wrong: #{msg}")
  end

  # Make sure author/editor callbacks are updating contributions right.
  def assert_contributions(rolf_score, mary_score, dick_score, katrina_score,
                           msg)
    [
      [rolf_score, rolf],
      [mary_score, mary],
      [dick_score, dick],
      [katrina_score, katrina]
    ].each do |score, user|
      assert_equal(10 + score, user.reload.contribution,
                   "Contribution for #{user.login} wrong: #{msg}")
    end
  end

  ##############################################################################

  # ------------------------------------------------------------------
  #  Make sure all the author/editor-related magic is working right.
  # ------------------------------------------------------------------

  def test_authors_and_editors
    [LocationDescription, NameDescription].each do |model|
      case model.name
      when "LocationDescription"
        obj = model.new(location_id: locations(:albion).id,
                        license_id: licenses(:ccnc25).id)
        a = 50
        e = 5
        set_nontrivial = "notes="
      when "NameDescription"
        obj = model.new(name_id: names(:fungi).id,
                        license_id: licenses(:ccnc25).id)
        a = 100
        e = 10
        set_nontrivial = "gen_desc="
      end

      msg = "#{model}: Initial conditions."
      assert_authors_and_editors(obj, [], [], msg)
      assert_contributions(0, 0, 0, 0, msg)

      # Have Rolf create minimal object.
      User.current = rolf
      assert_save(obj)
      msg = "#{model}: Rolf should not be made author after minimal create."
      assert_authors_and_editors(obj, [], ["rolf"], msg)
      assert_contributions(e, 0, 0, 0, msg)

      # Have Rolf make a trivial change.
      User.current = rolf
      obj.license_id = 2
      obj.save
      msg = "#{model}: Rolf should still be editor after trivial change."
      assert_authors_and_editors(obj, [], ["rolf"], msg)
      assert_contributions(e, 0, 0, 0, msg)

      # Delete editors and author so we can test changes to old object that
      # is grandfathered in without any editors or authors.
      User.current = nil # (stops AbstractModel from screwing up contributions)
      obj.update_users_and_parent
      obj.authors.clear
      obj.editors.clear
      msg = "#{model}: Just deleted authors and editors."
      assert_authors_and_editors(obj, [], [], msg)
      assert_contributions(0, 0, 0, 0, msg)

      # Now have Mary make a trivial change.  Should have same result as when
      # creating above.
      User.current = mary
      obj.license_id = 1
      obj.save
      msg = "#{model}: Mary should not be made author "\
            "after trivial change to authorless object."
      assert_authors_and_editors(obj, [], ["mary"], msg)
      assert_contributions(0, e, 0, 0, msg)

      # Now have Dick make a non-trivial change.
      obj.send(set_nontrivial, "This is weighty stuff...")
      User.current = dick
      obj.save
      msg = "#{model}: No authors, so Dick should become author."
      assert_authors_and_editors(obj, ["dick"], ["mary"], msg)
      assert_contributions(0, e, a, 0, msg)

      # Now have Katrina make another non-trivial change.
      obj.send(set_nontrivial, "This is even weightier stuff...")
      User.current = katrina
      obj.save
      msg = "#{model}: Already authors, so Katrina should become editor."
      assert_authors_and_editors(obj, ["dick"], %w[mary katrina], msg)
      assert_contributions(0, e, a, e, msg)

      # Now force Dick and Mary both to be both authors and editors.
      # Should equalize the two cases at last.
      obj.add_author(dick)
      obj.add_author(mary)
      obj.add_editor(dick)
      obj.add_editor(mary)
      msg = "#{model}: Both Dick and Mary were just made authors supposedly."
      assert_authors_and_editors(obj, %w[dick mary], ["katrina"], msg)
      assert_contributions(0, a, a, e, msg)

      # And demote an author to test last feature.
      obj.remove_author(dick)
      msg = "#{model}: Dick was just demoted supposedly."
      assert_authors_and_editors(obj, ["mary"], %w[dick katrina], msg)
      assert_contributions(0, a, e, e, msg)

      # Delete it to restore all contributions.
      obj.destroy
      msg = "#{model}: Just deleted the object."
      assert_contributions(0, 0, 0, 0, msg)
    end
  end

  def test_parent_setters
    albion = locations(:albion)
    obj = LocationDescription.new(location_id: albion.id,
                                  license_id: licenses(:ccnc25).id)
    burbank = locations(:burbank)
    obj.parent = burbank
    assert obj.parent_id == burbank.id
    obj.parent_id = albion.id
    assert obj.parent == albion
  end

  def test_permitted?
    desc = name_descriptions(:peltigera_user_desc)
    table = desc.readers_join_table

    assert(desc.permitted?(table, users(:dick)),
           "Dick should have read permission")
    assert_not(desc.permitted?(table, users(:katrina)),
               "Katrina should not have read permission")
    assert_not(desc.permitted?(table, nil),
               "Nil should not have read permission")
    assert(desc.permitted?(table, users(:dick).id.to_s),
           "`permitted?` should accept user.id")
    error = assert_raises(Exception) { desc.permitted?(table, "bad argument") }
    assert_equal(ArgumentError, error.class)
  end
end
