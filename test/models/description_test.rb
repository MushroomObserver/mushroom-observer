# frozen_string_literal: true

require("test_helper")

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

  def test_is_editor
    desc = name_descriptions(:suillus_desc)

    assert(desc.is_editor?(rolf))
    assert(desc.is_editor?(mary))
    assert_not(desc.is_editor?(katrina))
  end

  def test_parent_setters
    albion = locations(:albion)
    obj = LocationDescription.new(location_id: albion.id,
                                  license_id: licenses(:ccnc25).id)
    burbank = locations(:burbank)
    obj.parent = burbank
    assert(obj.parent_id == burbank.id)
    obj.parent_id = albion.id
    assert(obj.parent == albion)
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

  def test_formats
    desc = name_descriptions(:suillus_desc)
    assert_match(
      /^Public Description of /, desc.text_name,
      "Description text_name should start with description source type"
    )
    assert_match(/#{desc.parent.search_name}$/, desc.text_name,
                 "Description text_name should end with parent's search_name")
    assert_equal(ActionView::Base.full_sanitizer.sanitize(desc.text_name),
                 desc.text_name,
                 "Description text_name should not have HTML")

    assert_match(desc.id.to_s, desc.unique_text_name,
                 "Description unique_text_name should include id")

    assert_match(desc.id.to_s, desc.unique_format_name,
                 "Description unique_format_name should include id")

    assert_no_match(desc.parent.text_name, desc.partial_text_name,
                    "Description partial_text_name should omit parent")

    assert_no_match(desc.parent.text_name, desc.unique_partial_text_name,
                    "Description unique_partial_text_name should omit parent")
    assert_match(desc.id.to_s, desc.unique_partial_text_name,
                 "Description unique_partial_text_name should include id")
  end

  def test_user_sourced_description_with_unknown_user
    desc = name_descriptions(:peltigera_user_desc)
    desc.update(user_id: nil)

    assert(desc.text_name.start_with?("?'s "),
           "text_name of user sourced Description with unknown user should " \
           "start_with \"?'s\" ")
  end

  def test_source_object
    desc = name_descriptions(:suillus_desc) # public source
    assert_nil(desc.source_object)

    desc = name_descriptions(:peltigera_user_desc)
    assert_equal(desc.user, desc.source_object)

    desc = name_descriptions(:draft_boletus_edulis)
    assert_equal(desc.project, desc.source_object)
  end

  def test_groups
    desc = name_descriptions(:coprinus_comatus_desc)
    assert_equal([rolf], desc.admins)
    assert_equal([rolf.id], desc.admin_ids)
    assert_equal(User.all, desc.writers)
    assert_equal(User.pluck(:id), desc.writer_ids)
    assert_equal(User.all, desc.readers)
    assert_equal(User.pluck(:id), desc.reader_ids)

    desc = name_descriptions(:draft_coprinus_comatus)
    assert_equal([rolf, mary, katrina], desc.admins)
    assert_equal([rolf, mary, katrina].map(&:id), desc.admin_ids)
    assert_equal([rolf, mary, katrina], desc.writers)
    assert_equal([rolf, mary, katrina].map(&:id), desc.writer_ids)
    assert_equal([rolf, mary, katrina], desc.readers)
    assert_equal([rolf, mary, katrina].map(&:id), desc.reader_ids)
  end

  def test_add_remove_user_group_to_description_group
    desc = name_descriptions(:peltigera_user_desc)
    user_group = user_groups(:bolete_users)

    desc.add_admin(user_group)
    desc.add_writer(user_group)
    desc.add_reader(user_group)

    assert(desc.admins.include?(user_group))
    assert(desc.writers.include?(user_group))
    assert(desc.readers.include?(user_group))

    desc.remove_admin(user_group)
    desc.remove_writer(user_group)
    desc.remove_reader(user_group)

    assert(desc.admins.exclude?(user_group))
    assert(desc.writers.exclude?(user_group))
    assert(desc.readers.exclude?(user_group))
  end
end
