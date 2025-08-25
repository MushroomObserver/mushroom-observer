# frozen_string_literal: true

require("test_helper")

class NamesControllerUpdateMergeTest < FunctionalTestCase
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
  #  Update name -- with merge
  # ----------------------------

  def test_update_name_destructive_merge
    old_name = agaricus_campestrus = names(:agaricus_campestrus)
    new_name = agaricus_campestris = names(:agaricus_campestris)
    new_versions = new_name.versions.size
    old_obs = old_name.namings[0].observation
    new_obs = new_name.namings.
              find { |n| n.observation.name == new_name }.observation

    params = {
      id: old_name.id,
      name: {
        text_name: agaricus_campestris.text_name,
        author: agaricus_campestris.author,
        rank: "Species",
        deprecated: agaricus_campestris.deprecated
      }
    }
    login(rolf.login)

    # Fails because Rolf isn't in admin mode.
    put(:update, params: params)
    assert_redirected_to(new_admin_emails_merge_requests_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))
    assert(Name.find(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
    assert_equal(agaricus_campestrus, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)

    # Try again as an admin.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(3, new_name.namings.size)
    assert_equal(agaricus_campestris, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)
  end

  def test_update_name_author_merge
    # Names differing only in author
    old_name = names(:amanita_baccata_borealis)
    new_name = names(:amanita_baccata_arora)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_name.author,
        rank: "Species",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_author, new_name.reload.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Prove that user can remove author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_update_name_remove_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_authored)
    new_name   = names(:mergeable_epithet_unauthored)
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(new_name.id))
    assert_flash_success
    assert_empty(new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  # Prove that user can add author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_update_name_add_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_unauthored)
    new_name   = names(:mergeable_epithet_authored)
    new_author = new_name.author
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(new_name.id))
    assert_flash_success
    assert_equal(new_author, new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_remove_author_destructive_merge
    old_name = names(:authored_with_naming)
    new_name = names(:unauthored_with_naming)
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    login(rolf.login)
    put(:update, params: params)
    assert_redirected_to(new_admin_emails_merge_requests_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))

    # Try again as an admin.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_merge_author_has_notes
    bad_name = names(:hygrocybe_russocoriacea_bad_author)
    bad_id = bad_name.id
    bad_notes = bad_name.notes
    good_name = names(:hygrocybe_russocoriacea_good_author)
    good_id = good_name.id
    good_author = good_name.author
    params = {
      id: bad_name.id,
      name: {
        text_name: bad_name.text_name,
        author: good_author,
        notes: bad_notes,
        rank: "Species",
        deprecated: (bad_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    make_admin
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_id))
    assert_no_emails
    assert_not(Name.exists?(bad_id))
    reload_name = Name.find(good_id)
    assert(reload_name)
    assert_equal(good_author, reload_name.author)
    assert_match(/#{bad_notes}\Z/, reload_name.notes,
                 "old_name notes should be appended to target name's notes")
  end

  # Make sure misspelling gets transferred when new name merges away.
  def test_update_name_misspelling_merge
    old_name = names(:suilus)
    wrong_author_name = names(:suillus_by_white)
    new_name = names(:suillus)
    old_correct_spelling_id = old_name.correct_spelling_id
    params = {
      id: wrong_author_name.id,
      name: {
        text_name: wrong_author_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (wrong_author_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(wrong_author_name.id))
    assert_not_equal(old_correct_spelling_id,
                     old_name.reload.correct_spelling_id)
    assert_equal(old_name.correct_spelling, new_name)
  end

  # Test that merged names end up as not deprecated if the
  # new name is not deprecated.
  def test_update_name_deprecated_merge
    old_name = names(:lactarius_alpigenes)
    new_name = names(:lactarius_alpinus)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: "Species",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_not(new_name.deprecated)
    assert_equal(new_author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Test that merged name doesn't change deprecated status
  # unless the user explicitly changes status in form.
  def test_update_name_deprecated2_merge
    good_name = names(:lactarius_alpinus)
    bad_name1 = names(:lactarius_alpigenes)
    bad_name2 = names(:lactarius_kuehneri)
    bad_name3 = names(:lactarius_subalpinus)
    bad_name4 = names(:pluteus_petasatus_approved)
    good_text_name = good_name.text_name
    good_author = good_name.author

    # First: merge deprecated into accepted, no change.
    assert_not(good_name.deprecated)
    assert(bad_name1.deprecated)
    params = {
      id: bad_name1.id,
      name: {
        text_name: good_name.text_name,
        author: good_name.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name1.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(1, good_name.version)
    assert_equal(1, good_name.versions.size)

    # Second: merge accepted into deprecated, no change.
    good_name.change_deprecated(true)
    bad_name2.change_deprecated(false)
    good_name.skip_notify = true
    good_name.save
    bad_name2.skip_notify = true
    bad_name2.save
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    assert(good_name.deprecated)
    assert_not(bad_name2.deprecated)
    params[:id] = bad_name2.id
    params[:name][:deprecated] = "true"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name2.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    # Third: merge deprecated into deprecated, but change to accepted.
    assert(good_name.deprecated)
    assert(bad_name3.deprecated)
    params[:id] = bad_name3.id
    params[:name][:deprecated] = "false"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name3.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(3, good_name.version)
    assert_equal(3, good_name.versions.size)

    # Fourth: merge accepted into accepted, but change to deprecated.
    assert_not(good_name.deprecated)
    assert_not(bad_name4.deprecated)
    params[:id] = bad_name4.id
    params[:name][:deprecated] = "true"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name4.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(4, good_name.version)
    assert_equal(4, good_name.versions.size)
  end

  # Test merge two names where the new name has description notes.
  def test_update_name_merge_no_notes_into_description_notes
    old_name = names(:mergeable_no_notes)
    new_name = names(:mergeable_description_notes)
    notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(notes, new_name.description.notes)
  end

  # Test merge two names where the old name had notes.
  def test_update_name_merge_matching_notes2
    old_name = names(:russula_brevipes_author_notes)
    new_name = names(:conocybe_filaris)
    old_citation = old_name.citation
    old_notes = old_name.notes
    old_desc = old_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: "",
        rank: old_name.rank,
        citation: old_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal("", new_name.author) # user explicitly set author to ""
    assert_equal(old_citation, new_name.citation)
    assert_match(/#{old_notes}\Z/, new_name.notes,
                 "old_name notes should be appended to target name's notes")
    assert_not_nil(new_name.description)
    assert_equal(old_desc, new_name.description.notes)
  end

  def test_update_name_merged_notes_contain_notes_from_both_names
    old_name = names(:hygrocybe_russocoriacea_bad_author) # has notes
    new_name = names(:russula_brevipes_author_notes)
    original_notes = new_name.notes
    old_name_notes = old_name.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: new_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_match(original_notes, new_name.reload.notes)
    assert_match(old_name_notes, new_name.notes)
  end

  def test_update_name_merge_notes_into_nil_notes
    old_name = names(:hygrocybe_russocoriacea_bad_author) # has notes
    new_name = names(:russula_brevipes_author_notes)
    new_name.skip_notify = true
    new_name.update(notes: nil) # simulate survivor having nil notes
    old_name_notes = old_name.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: new_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    login(rolf.login)
    put(:update, params: params)

    assert_match(old_name_notes, new_name.reload.notes)
  end

  # Test merging two names, only one with observations.  Should work either
  # direction, but always keeping the name with observations.
  def test_update_name_merge_one_has_observations
    old_name = names(:mergeable_no_notes) # mergeable, ergo no observation
    assert(old_name.observations.none?, "Test needs a different fixture.")
    new_name = names(:coprinus_comatus) # has observations
    assert(new_name.observations.any?, "Test needs a different fixture.")

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_merge_one_has_observations_other_direction
    old_name = names(:coprinus_comatus) # has observations
    assert(old_name.observations.any?, "Test needs a different fixture.")
    new_name = names(:mergeable_no_notes) # mergeable, ergo no observations
    assert(new_name.observations.none?, "Test needs a different fixture.")

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(old_name.id))
    assert_no_emails
    assert(old_name.reload)
    assert_not(Name.exists?(new_name.id))
  end

  # Test merge two names that both start with notes.
  def test_update_name_merge_both_notes
    old_name = names(:mergeable_description_notes)
    new_name = names(:mergeable_second_description_notes)
    old_notes = old_name.description.notes
    new_notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (new_name.deprecated ? "true" : "false"),
        citation: ""
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_notes, new_name.description.notes)
    # Make sure old notes are still around.
    other_desc = (new_name.descriptions - [new_name.description]).first
    assert_equal(old_notes, other_desc.notes)
  end

  def test_edit_name_both_has_notes_and_namings
    old_name = names(:agaricus_campestros)
    new_name = names(:agaricus_campestras)
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: old_name.author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    # Fails normally.
    login(rolf.login)
    put(:update, params: params)
    assert_redirected_to(new_admin_emails_merge_requests_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))
    assert(old_name.reload)
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(1, new_name.namings.size)
    assert_equal(1, old_name.namings.size)
    assert_not_equal(new_name.namings[0], old_name.namings[0])

    # Try again in admin mode.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_raises(ActiveRecord::RecordNotFound) do
      assert(old_name.reload)
    end
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
  end

  # Prove that name_tracker is moved to new_name
  # when old_name with notication is merged to new_name
  def test_update_name_merge_with_name_tracker
    note = name_trackers(:no_observation_name_tracker)
    old_name = note.name
    new_name = names(:fungi)
    login(old_name.user.name)
    make_admin(old_name.user.login)
    change_old_name_to_new_name_params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        rank: "Genus",
        deprecated: "false"
      }
    }

    put(:update, params: change_old_name_to_new_name_params)
    note.reload

    assert_equal(new_name.id, note.name_id,
                 "Name Tracker was not redirected to target of Name merger")
  end

  # Test that misspellings are handle right when merging.
  def test_update_name_merge_with_misspellings
    login(rolf.login)
    name1 = names(:lactarius_alpinus)
    name1.skip_notify = true
    name2 = names(:lactarius_alpigenes)
    name2.skip_notify = true
    name3 = names(:lactarius_kuehneri)
    name3.skip_notify = true
    name4 = names(:lactarius_subalpinus)
    name4.skip_notify = true

    # First: merge Y into X, where Y is misspelling of X
    name2.correct_spelling = name1
    name2.change_deprecated(true)
    name2.skip_notify = true
    name2.save
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)
    assert(name2.correct_spelling == name1)
    assert(name2.deprecated)
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "true"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)

    # Second: merge Y into X, where X is misspelling of Y
    name1.correct_spelling = name3
    name1.change_deprecated(true)
    name1.skip_notify = true
    name1.save
    name3.correct_spelling = nil
    name3.change_deprecated(false)
    name3.skip_notify = true
    name3.save
    assert(name1.correct_spelling == name3)
    assert(name1.deprecated)
    assert_not(name3.correct_spelling)
    assert_not(name3.deprecated)
    params = {
      id: name3.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name3.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)

    # Third: merge Y into X, where X is misspelling of Z
    name1.correct_spelling = Name.first
    name1.change_deprecated(true)
    name1.skip_notify = true
    name1.save
    name4.correct_spelling = nil
    name4.change_deprecated(false)
    name4.skip_notify = true
    name4.save
    assert(name1.correct_spelling)
    assert(name1.correct_spelling != name4)
    assert(name1.deprecated)
    assert_not(name4.correct_spelling)
    assert_not(name4.deprecated)
    params = {
      id: name4.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name4.id))
    assert(name1.reload)
    assert(name1.correct_spelling == Name.first)
    assert(name1.deprecated)
  end

  # Found this in the wild, it seems to have been fixed already, though...
  def test_update_name_merge_authored_misspelt_into_unauthored_correctly_spelled
    login(rolf.login)

    name2 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae",
      sort_name: "Russula sect. Compactae",
      display_name: "**__Russula__** sect. **__Compactae__**",
      author: "",
      rank: "Section",
      deprecated: false,
      correct_spelling: nil,
      user: rolf
    )
    name1 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae Fr.",
      sort_name: "Russula sect. Compactae Fr.",
      display_name: "__Russula__ sect. __Compactae__ Fr.",
      author: "Fr.",
      rank: "Section",
      deprecated: true,
      correct_spelling: name2,
      user: rolf
    )
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Section",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)
    assert_equal("Russula sect. Compactae", name1.text_name)
    assert_equal("Fr.", name1.author)
  end

  # Merge, trying to change only identifier of surviving name
  def test_update_name_merge_retain_identifier
    edited_name = names(:stereum_hirsutum)
    surviving_name = names(:coprinus_comatus)
    assert(old_identifier = surviving_name.icn_id)

    params = {
      id: edited_name.id,
      name: {
        icn_id: old_identifier + 1_111_111,
        text_name: surviving_name.text_name,
        author: surviving_name.author,
        rank: surviving_name.rank,
        deprecated: (surviving_name.deprecated ? "true" : "false")
      }
    }

    login(rolf.login)
    assert_no_difference("surviving_name.version") do
      put(:update, params: params)
      surviving_name.reload
    end

    assert_flash_success
    assert_redirected_to(name_path(surviving_name.id))
    assert_email_generated # email admin re icn_id conflict
    assert_not(Name.exists?(edited_name.id))
    assert_equal(
      old_identifier, surviving_name.reload.icn_id,
      "Merge should retain icn_id if it exists"
    )
  end

  def test_update_name_merge_add_identifier
    edited_name = names(:amanita_boudieri_var_beillei)
    survivor = names(:amanita_boudieri)
    assert_nil(edited_name.icn_id, "Test needs fixtures without icn_id")
    assert_nil(survivor.icn_id, "Test needs fixtures without icn_id")

    edited_name.user_log(nil, "create edited_name log")

    destroyed_real_search_name = edited_name.user_real_search_name
    destroyed_display_name = edited_name.user_display_name

    params = {
      id: edited_name.id,
      name: {
        icn_id: 208_785,
        text_name: survivor.text_name,
        author: edited_name.author,
        rank: survivor.rank,
        deprecated: (survivor.deprecated ? "true" : "false")
      }
    }
    user = users(:rolf)
    login(user.login)

    assert_difference("survivor.versions.count", 1) do
      put(:update, params: params)
    end

    assert_redirected_to(name_path(survivor.id))

    expect = "Successfully merged name #{destroyed_real_search_name} " \
             "into #{survivor.user_real_search_name(user)}"
    assert_flash_text(/#{expect}/, "Merger success flash is incorrect")

    assert_no_emails
    assert_not(Name.exists?(edited_name.id))
    assert_equal(208_785, survivor.reload.icn_id)

    log = RssLog.last.parse_log
    assert_equal(:log_orphan, log[0][0])
    assert_equal({ title: destroyed_display_name }, log[0][1])
    assert_equal(:log_name_merged, log[1][0])
    assert_equal({ this: destroyed_display_name,
                   that: survivor.user_display_name,
                   user: "rolf" }, log[1][1])
  end

  def test_update_name_reverse_merge_add_identifier
    edited_name = names(:coprinus_comatus)
    merged_name = names(:stereum_hirsutum) # has empty icn_id
    assert_nil(merged_name.icn_id, "Test needs a fixture without icn_id")

    params = {
      id: edited_name.id,
      name: {
        icn_id: 189_826,
        text_name: merged_name.text_name,
        author: merged_name.author,
        rank: merged_name.rank,
        deprecated: (merged_name.deprecated ? "true" : "false")
      }
    }

    login(rolf.login)
    # merged_name is merged into edited_name because former has name proposals
    # and the latter does not
    assert_difference("edited_name.version") do
      put(:update, params: params)
      edited_name.reload
    end

    assert_flash_success
    assert_redirected_to(name_path(edited_name.id))
    assert_no_emails
    assert_not(Name.exists?(merged_name.id))
    assert_equal(189_826, edited_name.reload.icn_id)
  end

  def test_update_name_multiple_matches
    old_name = names(:agaricus_campestrus)
    new_name = names(:agaricus_campestris)
    duplicate = new_name.dup
    duplicate.save(validate: false)

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: new_name.deprecated
      }
    }
    login(rolf.login)
    make_admin

    assert_no_difference("Name.count") do
      put(:update, params: params)
    end
    assert_response(:success) # form reloaded
    assert_flash_error(:edit_name_multiple_names_match.l)
  end
end
