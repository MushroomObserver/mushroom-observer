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
      assert_equal(score + 10, user.reload.contribution,
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
      msg = "#{model}: Mary should not be made author " \
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

  # ------------------------------------------------------------------

  def test_destroy_default_description
    name = names(:suillus)
    desc = name.description
    desc.destroy

    assert_nil(name.reload.description,
               "Destroying default description should reset name.description")
  end

  def test_editor
    desc = name_descriptions(:coprinus_comatus_desc)

    assert(desc.editor?(mary),
           "Mary should be an editor of #{desc.text_name}")
    assert(desc.editor?(rolf),
           "Rolf should be an editor of #{desc.text_name}")
    assert_not(desc.editor?(katrina),
               "Katrina should be an editor of #{desc.text_name}")
  end

  def test_parent_setters
    albion = locations(:albion)
    obj = LocationDescription.new(location_id: albion.id,
                                  license_id: licenses(:ccnc25).id)
    burbank = locations(:burbank)
    obj.parent = burbank
    assert_equal(burbank.id, obj.parent_id)
    obj.parent_id = albion.id
    assert_equal(albion, obj.parent)
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
    assert_instance_of(ArgumentError, error)
  end

  def test_formats
    desc = name_descriptions(:suillus_desc)
    assert(desc.text_name.start_with?("Public Description of "),
           "Description text_name should start with description source type")
    assert(desc.text_name.end_with?(desc.parent.search_name),
           "Description text_name should end with parent's search_name")
    assert_equal(ActionView::Base.full_sanitizer.sanitize(desc.text_name),
                 desc.text_name,
                 "Description text_name should not have HTML")

    assert_includes(desc.unique_text_name, desc.id.to_s,
                    "Description unique_text_name should include id")

    assert_includes(desc.unique_format_name, desc.id.to_s,
                    "Description unique_format_name should include id")

    assert(desc.partial_text_name.exclude?(desc.parent.text_name),
           "Description partial_text_name should omit parent")

    assert(desc.unique_partial_text_name.exclude?(desc.parent.text_name),
           "Description unique_partial_text_name should omit parent")
    assert_includes(desc.unique_partial_text_name, desc.id.to_s,
                    "Description unique_partial_text_name should include id")
  end

  def test_user_sourced_description_with_unknown_user
    desc = name_descriptions(:peltigera_user_desc)
    desc.update(user_id: nil)

    # User-source description with unknown user: the user-source
    # title format still applies (the description's
    # `source_type` is "user" regardless of whether the user
    # record exists), but the `[USER]` placeholder falls back to
    # the "?" sentinel from `put_together_name`'s rescue branch.
    # Prior to the source_type-shadow bug fix this asserted
    # "Public" because the buggy local-variable shadow made every
    # description render with the public-source title format.
    assert(desc.text_name.start_with?("?'s"),
           "text_name of user-sourced description with unknown user " \
           "should start with the user-source format and an `?` " \
           "placeholder — got #{desc.text_name.inspect}")
  end

  # ---- source_type-specific title formats ------------------------
  #
  # Each `Description` source_type maps to its own i18n key — see
  # `description_{full,part}_title_<type>` in `en.txt`. The
  # `put_together_name` shadow bug masked these differences for
  # years (every description rendered with the `_public` format
  # regardless of its actual `source_type`); pin each format
  # explicitly so regressions don't silently re-flatten everything
  # back to "Public" again.

  # `description_part_title_public_with_text: "[TEXT]"`. A public
  # description with a `source_name` just renders the source_name
  # verbatim.
  def test_partial_text_name_public_source_with_text
    desc = name_descriptions(:peltigera_alt_desc) # source_type :public
    desc.update(source_name: "Wikipedia")
    assert_equal("public", desc.source_type)

    assert_equal("Wikipedia", desc.partial_text_name)
  end

  # `description_part_title_user_with_text: "[TEXT] by [USER]"`.
  def test_partial_text_name_user_source_with_text
    desc = name_descriptions(:peltigera_user_desc) # user mary
    desc.update(source_name: "Mary's Take")

    assert_equal("user", desc.source_type)
    assert_equal("Mary's Take by Mary Newbie", desc.partial_text_name)
  end

  # `description_part_title_user: "[USER]'s [:DESCRIPTION]"` (no
  # text variant).
  def test_partial_text_name_user_source_without_text
    desc = name_descriptions(:peltigera_user_desc)
    desc.update(source_name: nil)

    assert_equal("Mary Newbie's Description", desc.partial_text_name)
  end

  # `description_part_title_project_with_text: Draft for [TEXT] by [USER]`.
  def test_partial_text_name_project_source_with_text
    desc = name_descriptions(:draft_coprinus_comatus) # project draft
    assert_equal("project", desc.source_type)
    assert_predicate(desc.source_name, :present?)

    assert_equal("Draft for #{desc.source_name} by #{desc.user.legal_name}",
                 desc.partial_text_name)
  end

  # `description_part_title_source_with_text: "[:DESCRIPTION] From [TEXT]"`.
  def test_partial_text_name_source_source_with_text
    desc = name_descriptions(:peltigera_source_desc)
    assert_equal("source", desc.source_type)
    assert_predicate(desc.source_name, :present?)

    assert_equal("Description From #{desc.source_name}",
                 desc.partial_text_name)
  end

  # `description_full_title_public: Public [:DESCRIPTION] of [object]`
  # — the no-text public format, used in `text_name`.
  def test_text_name_public_source_no_text
    desc = name_descriptions(:suillus_desc)
    desc.update(source_name: nil)

    assert(desc.text_name.start_with?("Public Description of "),
           "Expected public-no-text format, got #{desc.text_name.inspect}")
  end

  # `description_full_title_project: Draft of [object] for [text] by [user]`.
  def test_text_name_project_source
    desc = name_descriptions(:draft_coprinus_comatus)
    expected_prefix = "Draft of "

    assert(desc.text_name.start_with?(expected_prefix),
           "Expected project full title prefix, got " \
           "#{desc.text_name.inspect}")
    assert_includes(desc.text_name, desc.source_name)
    assert_includes(desc.text_name, desc.user.legal_name)
  end

  # When `source_type` is nil (legacy / direct-attribute write),
  # `put_together_name` falls back to `:public`. Re-pins the
  # explicit fallback path so a future refactor doesn't drop it.
  def test_nil_source_type_falls_back_to_public_format
    desc = name_descriptions(:suillus_desc)
    # Bypass the AR enum validation so we can set the raw nil.
    desc.update_columns(source_type: nil)
    desc.reload

    assert_nil(desc.source_type)
    assert(desc.text_name.start_with?("Public Description of "),
           "Nil source_type should default to public format — got " \
           "#{desc.text_name.inspect}")
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
    # Must order on :id because of new table index on `login`
    assert_equal(User.order(:id).pluck(:id), desc.writer_ids)
    assert_equal(User.all, desc.readers)
    assert_equal(User.order(:id).pluck(:id), desc.reader_ids)

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

    assert_includes(desc.admins, user_group)
    assert_includes(desc.writers, user_group)
    assert_includes(desc.readers, user_group)

    desc.remove_admin(user_group)
    desc.remove_writer(user_group)
    desc.remove_reader(user_group)

    assert(desc.admins.exclude?(user_group))
    assert(desc.writers.exclude?(user_group))
    assert(desc.readers.exclude?(user_group))
  end
end
