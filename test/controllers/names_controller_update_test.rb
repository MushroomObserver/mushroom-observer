# frozen_string_literal: true

require("test_helper")

class NamesControllerUpdateTest < FunctionalTestCase
  tests NamesController
  include ObjectLinkHelper

  # EMAIL TESTS, currently in Names, Locations and their Descriptions
  # Has to be defined on class itself, include doesn't seem to work
  def self.report_email(email)
    @@emails ||= []
    @@emails << email
  end

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def assert_email_generated
    assert_not_empty(@@emails, "Was expecting an email notification.")
  ensure
    @@emails = []
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  # ----------------------------
  #  Edit name -- without merge
  # ----------------------------

  def test_edit_name_get_accepted_species
    name = names(:coprinus_comatus)
    params = { id: name.id.to_s }

    requires_login(:edit, params)

    assert_form_action(action: :update, id: name.id.to_s)
    assert_select("select#name_rank") do
      assert_select("option[selected]", text: "Species")
    end
    assert_select("select#name_deprecated") do
      assert_select("option[selected]", text: :ACCEPTED.l)
    end
    assert_select("form #name_icn_id", { count: 1 },
                  "Form is missing field for icn_id")
  end

  def test_edit_name_get_deprecated_genus
    name = names(:petigera)
    params = { id: name.id.to_s }

    requires_login(:edit, params)

    assert_form_action(action: :update, id: name.id.to_s)
    assert_select("select#name_rank") do
      assert_select("option[selected]", text: "Genus")
    end
    assert_select("select#name_deprecated") do
      assert_select("option[selected]", text: :DEPRECATED.l)
    end
    assert_select("form #name_icn_id", { count: 1 },
                  "Form is missing field for icn_id")
  end

  def test_edit_name_post
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_blank(name.author)
    assert_equal(1, name.version)
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "(Fr.) Kühner",
        rank: "Species",
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    put_requires_login(:update, params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(10, rolf.reload.contribution)
    assert_equal("(Fr.) Kühner", name.reload.author)
    assert_equal("**__Conocybe__** **__filaris__** (Fr.) Kühner",
                 name.user_display_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
  end

  # Regression test for bug where adding an author to a name without one
  # incorrectly redirected to the approve/deprecate synonyms screen.
  # The bug was caused by Phlex omitting the value attribute for boolean false,
  # so params[:name][:deprecated] was empty instead of "false".
  def test_edit_name_add_author_does_not_redirect_to_synonyms
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_blank(name.author)
    assert_equal(false, name.deprecated)

    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "New Author",
        rank: "Species",
        deprecated: "false" # Must be string "false", not empty or boolean
      }
    }
    login("rolf")
    put(:update, params: params)

    # Should redirect to the name show page, NOT to approve/deprecate synonyms
    assert_redirected_to(name_path(name.id))
    assert_no_match(/synonyms/, @response.redirect_url.to_s)
    assert_flash_success

    # Verify the author was saved
    assert_equal("New Author", name.reload.author)
    # Verify deprecated status unchanged
    assert_equal(false, name.deprecated)
  end

  def test_edit_name_no_changes
    name = names(:conocybe_filaris)
    text_name = name.text_name
    author = name.author
    rank = name.rank
    citation = name.citation
    deprecated = name.deprecated
    params = {
      id: name.id,
      name: {
        text_name: text_name,
        author: author,
        rank: rank,
        citation: citation,
        deprecated: (deprecated ? "true" : "false")
      }
    }
    user = name.user
    contribution = user.contribution
    login(user.login)
    put(:update, params: params)

    assert_flash_text(:runtime_no_changes.l)
    assert_redirected_to(name_path(name.id))
    assert_equal(text_name, name.reload.text_name)
    assert_equal(author, name.author)
    assert_equal(rank, name.rank)
    assert_equal(citation, name.citation)
    assert_equal(deprecated, name.deprecated)
    assert_equal(user, name.user)
    assert_equal(contribution, user.contribution)
  end

  # This catches a bug that was happening when editing a name that was in use.
  # In this case text_name and author are missing, confusing edit_name.
  def test_edit_name_post_name_and_author_missing
    names(:conocybe).destroy
    name = names(:conocybe_filaris)
    params = {
      id: name.id,
      name: {
        rank: "Species",
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal("", name.reload.author)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_edit_name_unchangeable_plus_admin_email
    name = names(:other_user_owns_naming_name)
    user = name.user
    contribution = user.contribution
    # Change the first word
    desired_text_name = name.text_name.
                        sub(/\S+/, "Big-change-to-force-email-to-admin")
    params = {
      id: name.id,
      name: {
        text_name: desired_text_name,
        author: "",
        rank: name.rank,
        deprecated: "false"
      }
    }
    login(name.user.login)
    put(:update, params: params)
    # This does not generate a new_admin_emails_name_change_requests_path email,
    # both because this name has no dependents,
    # and because the email form requires a POST.
    assert(@@emails.one?)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(desired_text_name, name.reload.search_name)
    assert_equal(contribution, user.reload.contribution)
  end

  def test_edit_name_post_just_change_notes
    # has blank notes
    name = names(:conocybe_filaris)
    past_names = name.versions.size
    new_notes = "Add this to the notes."
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "",
        rank: "Species",
        citation: "",
        notes: new_notes,
        deprecated: (name.deprecated ? "true" : "false")

      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    assert_equal(new_notes, name.reload.notes)
    assert_equal(past_names + 1, name.versions.size)
  end

  def test_edit_deprecated_name_remove_author
    name = names(:lactarius_alpigenes)
    assert(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: "",
        rank: "Species",
        citation: "new citation",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(mary.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_email_generated
    assert(Name.exists?(text_name: "Lactarius"))
    # points for changing Lactarius alpigenes
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert(name.reload.deprecated)
    assert_equal("new citation", name.citation)
  end

  def test_edit_name_add_author
    name = names(:strobilurus_diminutivus_no_author)
    old_text_name = name.text_name
    new_author = "Desjardin"
    params = {
      id: name.id,
      name: {
        text_name: old_text_name,
        author: new_author,
        rank: "Species",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(mary.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert_equal(new_author, name.reload.author)
    assert_equal(old_text_name, name.text_name)
  end

  # Prove that user can change name -- without merger --
  # if there's no exact match to desired Name
  def test_edit_name_remove_author_no_exact_match
    name = names(:amanita_baccata_arora)
    params = {
      id: name.id,
      name: {
        text_name: names(:coprinus_comatus).text_name,
        author: "",
        rank: names(:coprinus_comatus).rank,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(name.id))
    assert_flash_success
    assert_empty(name.reload.author)
    assert_email_generated
  end

  def test_edit_name_misspelling
    login(rolf.login)

    # Prove we can clear misspelling by unchecking "misspelt" box
    name = names(:petigera)
    assert_true(name.reload.is_misspelling?)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "true",
        misspelling: ""
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_false(name.reload.is_misspelling?)
    assert_nil(name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(name_path(name.id))

    # Prove we can deprecate and call a name misspelt by checking box and
    # entering correct spelling.
    name.deprecated = false
    name.skip_notify = true
    name.save!
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "false",
        misspelling: "1",
        correct_spelling: "Peltigera"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_true(name.reload.is_misspelling?)
    assert_equal("__Petigera__", name.user_display_name)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(name_path(name.id))

    # Prove we cannot correct misspelling with unrecognized Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: "Qwertyuiop"
      }
    }
    put(:update, params: params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we cannot correct misspelling with same Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: name.text_name
      }
    }
    put(:update, params: params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we can swap misspelling and correct_spelling
    # Change "Suillus E.B. White" to "Suilus E.B. White"
    old_misspelling = names(:suilus)
    old_correct_spelling = old_misspelling.correct_spelling
    params = {
      id: old_correct_spelling.id,
      name: {
        text_name: old_correct_spelling.text_name,
        author: old_correct_spelling.author,
        rank: old_correct_spelling.rank,
        deprecated: (old_correct_spelling.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: old_misspelling.text_name
      }
    }
    put(:update, params: params)
    # old_correct_spelling's spelling status and deprecation should change
    assert(old_correct_spelling.reload.is_misspelling?)
    assert_equal(old_misspelling, old_correct_spelling.correct_spelling)
    assert(old_correct_spelling.deprecated)
    # old_misspelling's spelling status should change but deprecation should not
    assert_not(old_misspelling.reload.is_misspelling?)
    assert_empty(old_misspelling.correct_spelling)
    assert(old_misspelling.deprecated)
  end

  def test_edit_name_by_user_who_doesnt_own_name
    name = names(:macrolepiota_rhacodes)
    name_owner = name.user
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: "Species",
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_warning
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    # (But owner remains of course.)
    assert_equal(name_owner, name.reload.user)
  end

  def test_edit_name_chain_to_approve_and_deprecate
    login(rolf.login)
    name = names(:lactarius_alpigenes)
    params = {
      id: name.id,
      name: {
        rank: name.rank,
        text_name: name.text_name,
        author: name.author,
        citation: name.citation,
        notes: name.notes
      }
    }

    # No change: go to show_name, warning.
    params[:name][:deprecated] = "true"
    put(:update, params: params)
    assert_flash_warning
    assert_redirected_to(name_path(name.id))
    assert_no_emails

    # Change to accepted: go to approve_name, no flash.
    params[:name][:deprecated] = "false"
    put(:update, params: params)
    assert_no_flash
    assert_redirected_to(form_to_approve_synonym_of_name_path(name.id))

    # Change to deprecated: go to deprecate_name, no flash.
    name.skip_notify = true
    name.change_deprecated(false)
    name.save
    params[:name][:deprecated] = "true"
    put(:update, params: params)
    assert_no_flash
    assert_redirected_to(form_to_deprecate_synonym_of_name_path(name.id))
  end

  def test_edit_name_with_umlaut
    login(dick.login)
    names = Name.find_or_create_name_and_parents(dick,
                                                 "Xanthoparmelia coloradoensis")
    names.each(&:save)
    name = names.last
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia__** **__coloradoensis__**",
                 name.user_display_name)

    get(:edit, params: { id: name.id })
    assert_textarea_value("name_text_name", "Xanthoparmelia coloradoensis")
    assert_textarea_value("name_author", "")

    params = {
      id: name.id,
      name: {
        # (test what happens if user puts author in wrong field)
        text_name: "Xanthoparmelia coloradoënsis (Gyelnik) Hale",
        author: "",
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis (Gyelnik) Hale",
                 name.search_name)
    assert_equal("**__Xanthoparmelia__** **__coloradoënsis__** (Gyelnik) Hale",
                 name.user_display_name)

    get(:edit, params: { id: name.id })
    assert_textarea_value("name_text_name", "Xanthoparmelia coloradoënsis")
    assert_textarea_value("name_author", "(Gyelnik) Hale")

    params[:name][:text_name] = "Xanthoparmelia coloradoensis"
    params[:name][:author] = ""
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_email_generated
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia__** **__coloradoensis__**",
                 name.user_display_name)
  end

  def test_edit_name_fixing_variety
    login(katrina.login)
    name = Name.create!(
      text_name: "Pleurotus djamor",
      search_name: "Pleurotus djamor (Fr.) Boi var. djamor",
      sort_name: "Pleurotus djamor (Fr.) Boi var. djamor",
      display_name: "**__Pleurotus__** **__djamor__** (Fr.) Boi var. djamor",
      author: "(Fr.) Boi var. djamor",
      rank: "Species",
      deprecated: false,
      correct_spelling: nil,
      user: katrina
    )
    params = {
      id: name.id,
      name: {
        text_name: "Pleurotus djamor var. djamor (Fr.) Boi",
        author: "",
        rank: "Variety",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Variety", name.rank)
    assert_equal("Pleurotus djamor var. djamor", name.text_name)
    assert_equal("Pleurotus djamor var. djamor (Fr.) Boi", name.search_name)
    assert_equal("(Fr.) Boi", name.author)
    # In the bug in the wild, it was failing to create the parents.
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  def test_edit_name_change_to_group
    login(mary.login)
    name = Name.create!(
      text_name: "Lepiota echinatae",
      search_name: "Lepiota echinatae Group",
      sort_name: "Lepiota echinatae Group",
      display_name: "**__Lepiota__** **__echinatae__** Group",
      author: "Group",
      rank: "Species",
      deprecated: false,
      correct_spelling: nil,
      user: mary
    )
    params = {
      id: name.id,
      name: {
        text_name: "Lepiota echinatae",
        author: "Group",
        rank: "Group",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Group", name.rank)
    assert_equal("Lepiota echinatae group", name.text_name)
    assert_equal("Lepiota echinatae group", name.search_name)
    assert_equal("**__Lepiota__** **__echinatae__** group",
                 name.user_display_name)
    assert_equal("", name.author)
  end

  def test_edit_name_screwy_notification_bug
    login(mary.login)
    name = Name.create!(
      text_name: "Ganoderma applanatum",
      search_name: "Ganoderma applanatum",
      sort_name: "Ganoderma applanatum",
      display_name: "__Ganoderma__ __applanatum__",
      author: "",
      rank: "Species",
      deprecated: true,
      correct_spelling: nil,
      citation: "",
      notes: "",
      user: mary
    )
    Interest.create!(
      target: name,
      user: rolf,
      state: true
    )
    params = {
      id: name.id,
      name: {
        text_name: "Ganoderma applanatum",
        author: "",
        rank: "Species",
        deprecated: "true",
        citation: "",
        notes: "Changed notes."
      }
    }
    put(:update, params: params)
    # was crashing while notifying rolf because new version wasn't saved yet
    assert_flash_success
  end

  # Prove that editing can create multiple ancestors
  def test_edit_name_create_multiple_ancestors
    name        = names(:two_ancestors)
    new_name    = "Neo#{name.text_name.downcase}"
    new_species = new_name.sub(/(\w* \w*).*/, '\1')
    new_genus   = new_name.sub(/(\w*).*/, '\1')
    name_count  = Name.count
    params = {
      id: name.id,
      name: {
        text_name: new_name,
        author: name.author,
        rank: name.rank
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_equal(name_count + 2, Name.count)
    assert(Name.exists?(text_name: new_species), "Failed to create new species")
    assert(Name.exists?(text_name: new_genus), "Failed to create new genus")
  end

  def test_edit_and_update_locked_name
    name = names(:stereum_hirsutum)
    name.update(locked: true)
    params = {
      id: name.id,
      name: {
        locked: "0",
        icn_id: 666,
        rank: "Genus",
        deprecated: true,
        text_name: "Foo",
        author: "Bar",
        citation: "new citation",
        notes: "new notes"
      }
    }
    login(rolf.login)

    get(:edit, params: { id: name.id })
    # Rolf is not an admin, so form should not show locked fields as changeable
    assert_select("input[type=text]#name_icn_id", count: 0)
    assert_select("select#name_rank", count: 0)
    assert_select("select#name_deprecated", count: 0)
    assert_select("textarea#name_text_name", count: 0)
    assert_select("textarea#name_author", count: 0)
    assert_select("input[type=checkbox]#name_misspelling", count: 0)
    assert_select("input[type=text]#name_correct_spelling", count: 0)

    put(:update, params: params)
    name.reload
    # locked attributes should not change
    assert_true(name.locked)
    assert_nil(name.icn_id)
    assert_equal("Species", name.rank)
    assert_false(name.deprecated)
    assert_equal("Stereum hirsutum", name.text_name)
    assert_equal("(Willd.) Pers.", name.author)
    assert_nil(name.correct_spelling_id)
    # unlocked attributes should change
    assert_equal("new citation", name.citation)
    assert_equal("new notes", name.notes)

    make_admin(rolf.login)
    get(:edit, params: { id: name.id })
    assert_select("input[type=text]#name_icn_id", count: 1)
    assert_select("select#name_rank", count: 1)
    assert_select("select#name_deprecated", count: 1)
    assert_select("textarea#name_text_name", count: 1)
    assert_select("textarea#name_author", count: 1)
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)

    put(:update, params: params)
    name.reload
    assert_equal(params[:name][:icn_id], name.icn_id)
    assert_equal("Foo", name.text_name)
    assert_equal("Bar", name.author)
    assert_equal("Genus", name.rank)
    assert_false(name.locked)
    assert_redirected_to(form_to_deprecate_synonym_of_name_path(name.id))
  end

  def test_edit_misspelled_name
    misspelled_name = names(:suilus)
    login(rolf.login)
    get(:edit, params: { id: misspelled_name.id })
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)
  end

  def test_update_change_text_name_of_ancestor
    name = names(:boletus)
    params = {
      id: name.id,
      name: {
        text_name: "Superboletus",
        author: name.author,
        rank: name.rank
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_redirected_to(
      new_admin_emails_name_change_requests_path(
        name_id: name.id, new_name_with_icn_id: "Superboletus [#]"
      ),
      "User should be unable to change text_name of Name with dependents"
    )
  end

  def test_update_minor_change_to_ancestor
    name = names(:boletus)
    assert(name.children.present? &&
           name.icn_id.blank? && name.author.blank? && name.citation.blank?,
           "Test needs different fixture: " \
           "Name with a child, and without icn_id, author, or citation")
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        rank: name.rank,
        # adding these should be a minor change
        icn_id: "17175",
        author: "L.",
        citation: "Sp. pl. 2: 1176 (1753)"
      }
    }

    login(name.user.login)
    put(:update, params: params)

    assert_flash_success(
      "User should be able to make minor changes to Name that has offspring"
    )
    assert_no_emails
    name.reload
    assert_equal(params[:name][:icn_id], name.icn_id.to_s)
    assert_equal(params[:name][:author], name.author)
    assert_equal(params[:name][:citation], name.citation)
  end

  def test_update_change_text_name_of_approved_synonym
    approved_synonym = names(:lactarius_alpinus)
    deprecated_name = names(:lactarius_alpigenes)
    user = users(:rolf)
    login(user.login)
    Naming.create(name: deprecated_name,
                  observation: observations(:minimal_unknown_obs),
                  user:)
    assert(
      !approved_synonym.deprecated &&
        Naming.where(name: approved_synonym).none? &&
        deprecated_name.synonym == approved_synonym.synonym,
      "Test needs different fixture: " \
      "an Approved Name without Namings, with a synonym having Naming(s)"
    )
    changed_name = names(:agaricus_campestris) # can be any other name

    params = {
      id: approved_synonym.id,
      name: {
        text_name: changed_name.text_name,
        author: changed_name.author,
        rank: changed_name.rank,
        deprecated: changed_name.deprecated
      }
    }
    put(:update, params: params)

    assert_redirected_to(
      /#{new_admin_emails_name_change_requests_path}/,
      "User should be unable to change an approved synonym of a Naming"
    )
  end

  def test_update_add_icn_id
    name = names(:stereum_hirsutum)
    rank = name.rank
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: 189_826
      }
    }
    user = name.user
    login(user.login)

    assert_difference("name.versions.count", 1) do
      put(:update, params: params)
    end
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(189_826, name.reload.icn_id)
    assert_no_emails

    assert_equal(rank, Name.ranks.key(name.versions.first.rank),
                 "Rank versioned incorrectly.")
  end

  def test_update_icn_id_unchanged
    name = names(:coprinus_comatus)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name.icn_id,
        notes: "A zillion synonyms and other stuff copied from Index Fungorum"
      }
    }
    user = name.user
    login(user.login)

    assert_difference("name.versions.count", 1) do
      put(:update, params: params)
    end
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
  end

  def test_update_change_icn_id_name_with_dependents
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name.icn_id + 1,
        notes: name.notes
      }
    }
    user = name.user
    login(user.login)

    put(:update, params: params)
    assert_redirected_to(
      new_admin_emails_name_change_requests_path(
        name_id: name.id,
        new_name_with_icn_id: "#{name.search_name} [##{name.icn_id + 1}]"
      ),
      "Editing id# of Name w/dependents should show Name Change Request form"
    )
  end

  def test_update_icn_id_unregistrable
    name = names(:authored_group)
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: 189_826
      }
    }
    login
    put(:update, params: params)

    assert_flash_error(:name_error_unregistrable.l)
  end

  def test_update_icn_id_non_numeric
    name = names(:stereum_hirsutum)
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: "MB12345"
      }
    }
    default_validates_numericality_of_error_message = "is not a number"
    login
    put(:update, params: params)

    assert_flash_text(/#{default_validates_numericality_of_error_message}/)
  end

  def test_update_icn_id_duplicate
    name = names(:stereum_hirsutum)
    name_with_icn_id = names(:coprinus_comatus)
    assert(name_with_icn_id.icn_id, "Test needs a fixture with an icn_id")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name_with_icn_id.icn_id
      }
    }
    login
    put(:update, params: params)

    assert_flash_error(:name_error_icn_id_in_use.l)
  end
end
