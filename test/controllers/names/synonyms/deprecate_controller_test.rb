# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Synonyms
  class DeprecateControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_deprecate_name
      name = names(:chlorophyllum_rachodes)
      params = { id: name.id }
      requires_login(:new, params)
      assert_form_action(controller: "/names/synonyms/deprecate",
                         action: :create, approved_name: "",
                         id: name.id)
    end

    # ----------------------------
    #  Deprecation.
    # ----------------------------

    # deprecate an existing unique name with another existing name
    def test_do_deprecation
      old_name = names(:lepiota_rachodes)
      assert_not(old_name.deprecated)
      assert_nil(old_name.synonym_id)
      old_past_name_count = old_name.versions.length
      old_version = old_name.version

      new_name = names(:chlorophyllum_rachodes)
      assert_not(new_name.deprecated)
      assert_not_nil(new_name.synonym_id)
      new_synonym_length = new_name.synonyms.size
      new_past_name_count = new_name.versions.length
      new_version = new_name.version

      params = {
        id: old_name.id,
        proposed_name: new_name.text_name,
        comment: "Don't like this name"
      }
      post_requires_login(:create, params)
      assert_redirected_to(name_path(old_name.id))

      assert(old_name.reload.deprecated)
      assert_equal(old_past_name_count + 1, old_name.versions.length)
      assert(old_name.versions.latest.deprecated)
      assert_not_nil(old_synonym = old_name.synonym)
      assert_equal(old_version + 1, old_name.version)

      assert_not(new_name.reload.deprecated)
      assert_equal(new_past_name_count, new_name.versions.length)
      assert_not_nil(new_synonym = new_name.synonym)
      assert_equal(old_synonym, new_synonym)
      assert_equal(new_synonym_length + 1, new_synonym.names.size)
      assert_equal(new_version, new_name.version)

      comment = Comment.last
      assert_equal("Name", comment.target_type)
      assert_equal(old_name.id, comment.target_id)
      assert_match(/deprecat/i, comment.summary)
      assert_equal("Don't like this name", comment.comment)
    end

    # deprecate an existing unique name with an ambiguous name
    def test_do_deprecation_ambiguous
      old_name = names(:lepiota_rachodes)
      assert_not(old_name.deprecated)
      assert_nil(old_name.synonym_id)
      old_past_name_count = old_name.versions.length

      new_name = names(:amanita_baccata_arora) # Ambiguous text name
      assert_not(new_name.deprecated)
      assert_nil(new_name.synonym_id)
      new_past_name_count = new_name.versions.length

      comments = Comment.count

      params = {
        id: old_name.id,
        proposed_name: new_name.text_name,
        comment: ""
      }
      login("rolf")
      post(:create, params: params)
      assert_template("names/synonyms/deprecate/new")
      assert_template("shared/_form_name_feedback")
      # Fail since name can't be disambiguated

      assert_not(old_name.reload.deprecated)
      assert_equal(old_past_name_count, old_name.versions.length)
      assert_nil(old_name.synonym_id)

      assert_not(new_name.reload.deprecated)
      assert_equal(new_past_name_count, new_name.versions.length)
      assert_nil(new_name.synonym_id)

      assert_equal(comments, Comment.count)
    end

    # deprecate an existing unique name with an ambiguous name,
    # but using :chosen_name to disambiguate
    def test_do_deprecation_chosen
      old_name = names(:lepiota_rachodes)
      assert_not(old_name.deprecated)
      assert_nil(old_name.synonym_id)
      old_past_name_count = old_name.versions.length

      new_name = names(:amanita_baccata_arora) # Ambiguous text name
      assert_not(new_name.deprecated)
      assert_nil(new_name.synonym_id)
      new_past_name_count = new_name.versions.length

      params = {
        id: old_name.id,
        proposed_name: new_name.text_name,
        chosen_name: { name_id: new_name.id },
        comment: "Don't like this name"
      }
      login("rolf")
      post(:create, params: params)
      assert_redirected_to(name_path(old_name.id))

      assert(old_name.reload.deprecated)
      assert_equal(old_past_name_count + 1, old_name.versions.length)
      assert(old_name.versions.latest.deprecated)
      assert_not_nil(old_synonym = old_name.synonym)

      assert_not(new_name.reload.deprecated)
      assert_equal(new_past_name_count, new_name.versions.length)
      assert_not_nil(new_synonym = new_name.synonym)
      assert_equal(old_synonym, new_synonym)
      assert_equal(2, new_synonym.names.size)
    end

    # deprecate an existing unique name with an ambiguous name
    def test_do_deprecation_new_name
      old_name = names(:lepiota_rachodes)
      assert_not(old_name.deprecated)
      assert_nil(old_name.synonym_id)
      old_past_name_count = old_name.versions.length

      new_name_str = "New name"

      params = {
        id: old_name.id,
        proposed_name: new_name_str,
        comment: "Don't like this name"
      }
      login("rolf")
      post(:create, params: params)
      assert_template("names/synonyms/deprecate/new")
      assert_template("shared/_form_name_feedback")
      # Fail since new name is not approved

      assert_not(old_name.reload.deprecated)
      assert_equal(old_past_name_count, old_name.versions.length)
      assert_nil(old_name.synonym_id)
    end

    # deprecate an existing unique name with an ambiguous name,
    # but using :chosen_name to disambiguate
    def test_do_deprecation_approved_new_name
      old_name = names(:lepiota_rachodes)
      assert_not(old_name.deprecated)
      assert_nil(old_name.synonym_id)
      old_past_name_count = old_name.versions.length

      new_name_str = "New name"

      params = {
        id: old_name.id,
        proposed_name: new_name_str,
        approved_name: new_name_str,
        comment: "Don't like this name"
      }
      login("rolf")
      post(:create, params: params)
      assert_redirected_to(name_path(old_name.id))

      assert(old_name.reload.deprecated)
      # past name should have been created# past name should have been created
      assert_equal(old_past_name_count + 1, old_name.versions.length)
      assert(old_name.versions.latest.deprecated)
      assert_not_nil(old_synonym = old_name.synonym)

      new_name = Name.find_by(text_name: new_name_str)
      assert_not(new_name.deprecated)
      assert_not_nil(new_synonym = new_name.synonym)
      assert_equal(old_synonym, new_synonym)
      assert_equal(2, new_synonym.names.size)
    end

    def test_deprecate_name_locked
      name = Name.where(locked: true).first
      name2 = names(:agaricus_campestris)
      name.change_deprecated(false)
      name.save
      params = {
        id: name.id,
        proposed_name: name2.search_name,
        approved_name: name2.search_name,
        comment: ""
      }

      login("rolf")
      get(:new, params: { id: name.id })
      assert_response(:redirect)
      post(:create, params: params)
      assert_flash_error
      assert_false(name.reload.deprecated)

      make_admin("mary")
      get(:new, params: { id: name.id })
      assert_response(:success)
      post(:create, params: params)
      assert_true(name.reload.deprecated)
    end
  end
end
