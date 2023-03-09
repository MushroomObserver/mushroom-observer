# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Synonyms
  class ApproveControllerTest < FunctionalTestCase
    include ObjectLinkHelper
    # ----------------------------
    #  Approval.
    # ----------------------------

    def test_approve_name
      name = names(:lactarius_alpigenes)
      params = { id: name.id }
      requires_login(:new, params)
      assert_form_action(controller: "/names/synonyms/approve",
                         action: :create, id: name.id)
    end

    # approve a deprecated name
    def test_do_approval_default
      old_name = names(:lactarius_alpigenes)
      assert(old_name.deprecated)
      assert(old_name.synonym_id)
      old_past_name_count = old_name.versions.length
      old_version = old_name.version
      approved_synonyms = old_name.approved_synonyms

      params = {
        id: old_name.id,
        deprecate_others: "1",
        comment: "Prefer this name"
      }
      post_requires_login(:create, params)
      assert_redirected_to(name_path(old_name.id))

      assert_not(old_name.reload.deprecated)
      assert_equal(old_past_name_count + 1, old_name.versions.length)
      assert_not(old_name.versions.latest.deprecated)
      assert_equal(old_version + 1, old_name.version)

      approved_synonyms.each { |n| assert(n.reload.deprecated) }

      comment = Comment.last
      assert_equal("Name", comment.target_type)
      assert_equal(old_name.id, comment.target_id)
      assert_match(/approve/i, comment.summary)
      assert_equal("Prefer this name", comment.comment)
    end

    # approve a deprecated name, but don't deprecate the synonyms
    def test_do_approval_no_deprecate
      old_name = names(:lactarius_alpigenes)
      assert(old_name.deprecated)
      assert(old_name.synonym_id)
      old_past_name_count = old_name.versions.length
      approved_synonyms = old_name.approved_synonyms

      comments = Comment.count

      params = {
        id: old_name.id,
        deprecate_others: "0",
        comment: ""
      }
      login("rolf")
      post(:create, params: params)
      assert_redirected_to(name_path(old_name.id))

      assert_not(old_name.reload.deprecated)
      assert_equal(old_past_name_count + 1, old_name.versions.length)
      assert_not(old_name.versions.latest.deprecated)

      approved_synonyms.each { |n| assert_not(n.reload.deprecated) }
      assert_equal(comments, Comment.count)
    end

    def test_approve_name_locked
      name = Name.where(locked: true).first
      name.change_deprecated(true)
      name.save
      params = {
        id: name.id,
        deprecate_others: "0",
        comment: ""
      }

      login("rolf")
      get(:new, params: { id: name.id })
      assert_response(:redirect)
      post(:create, params: params)
      assert_flash_error
      assert_true(name.reload.deprecated)

      make_admin("mary")
      get(:new, params: { id: name.id })
      assert_response(:success)
      post(:create, params: params)
      assert_false(name.reload.deprecated)
    end
  end
end
