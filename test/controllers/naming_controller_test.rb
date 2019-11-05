# frozen_string_literal: true.

require "test_helper"

class NamingControllerTest < FunctionalTestCase
  def test_create_get
    obs = observations(:coprinus_comatus_obs)
    params = { id: obs.id.to_s }
    requires_login(:create, params)
    assert_form_action(action: "create", approved_name: "", id: obs.id.to_s)
  end

  def test_edit_get
    nam = namings(:coprinus_comatus_naming)
    params = { id: nam.id.to_s }
    requires_user(:edit, { controller: :observer, action: :show_observation,
                           id: nam.observation_id }, params)
    assert_form_action(action: "edit", approved_name: nam.text_name,
                       id: nam.id.to_s)
    assert_select("option[selected]", count: 2)

    login(nam.user.login)
    get(:edit, params)
    assert_no_flash(
      "User should be able to edit his own Naming without warning or error"
    )
  end

  def test_update_observation_new_name
    login("rolf")
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = { id: nam.id.to_s, name: { name: new_name } }
    post(:edit, params)
    assert_edit
    assert_equal(10, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
    assert_select("option[selected]", count: 2)
  end

  def test_update_observation_approved_new_name
    login("rolf")
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = {
      id: nam.id.to_s,
      name: { name: new_name },
      approved_name: new_name,
      vote: { value: 1 }
    }
    old_contribution = rolf.contribution

    # Clones naming, creates Easter sp and E. bunny, but no votes.
    post(:edit, params)
    params = assigns(:params)
    nam = params.naming

    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: nam.observation_id)
    assert_equal(new_name, nam.text_name)
    assert_not_equal(old_name, nam.text_name)
    assert_not(nam.name.deprecated)
    assert_equal(old_contribution + (SiteData::FIELD_WEIGHTS[:names] * 2) + 2,
                 rolf.reload.contribution)
  end

  def test_update_observation_multiple_match
    login("rolf")
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Amanita baccata"
    params = {
      id: nam.id.to_s,
      name: { name: new_name }
    }
    post(:edit, params)
    assert_edit
    assert_equal(10, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
    assert_select("option[selected]", count: 2)
  end

  def test_update_observation_chosen_multiple_match
    login("rolf")
    nmg = namings(:coprinus_comatus_naming)
    old_name = nmg.text_name
    new_name = "Amanita baccata"
    params = {
      id: nmg.id.to_s,
      name: { name: new_name },
      chosen_name: { name_id: names(:amanita_baccata_arora).id },
      vote: { value: 1 }
    }
    post(:edit, params)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: nmg.observation.id)
    # Must be cloning naming with no vote.
    assert_equal(12, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_equal(new_name, nam.name.text_name)
    assert_equal(new_name + " sensu Arora", nam.text_name)
    assert_not_equal(old_name, nam.text_name)
  end

  def test_update_observation_deprecated
    login("rolf")
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Lactarius subalpinus"
    params = {
      id: nam.id.to_s,
      name: { name: new_name }
    }
    post(:edit, params)
    assert_edit
    assert_equal(10, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
    assert_select("option[selected]", count: 2)
  end

  def test_update_observation_chosen_deprecated
    login("rolf")
    nmg = namings(:coprinus_comatus_naming)
    start_name = nmg.name
    new_name = "Lactarius subalpinus"
    chosen_name = names(:lactarius_alpinus)
    params = {
      id: nmg.id.to_s,
      name: { name: new_name },
      approved_name: new_name,
      chosen_name: { name_id: chosen_name.id },
      vote: { value: 1 }
    }
    post(:edit, params)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: nmg.observation.id)
    # Must be cloning naming, with no vote.
    assert_equal(12, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(chosen_name.id, nam.name_id)
  end

  def test_update_observation_accepted_deprecated
    login("rolf")
    nmg = namings(:coprinus_comatus_naming)
    start_name = nmg.name
    new_text_name = names(:lactarius_subalpinus).text_name
    params = {
      id: nmg.id.to_s,
      name: { name: new_text_name },
      approved_name: new_text_name,
      chosen_name: {},
      vote: { value: 3 }
    }
    post(:edit, params)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: nmg.observation.id)
    # Must be cloning the naming, but no votes?
    assert_equal(12, rolf.reload.contribution)
    params = assigns(:params)
    nam = params.naming
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(new_text_name, nam.name.text_name)
  end

  # Rolf makes changes to vote and reasons of his naming.  Shouldn't matter
  # whether Mary has voted on it.
  def test_edit_thats_being_used_just_change_reasons
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)

    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Rolf makes superficial changes to his naming.
    login("rolf")
    post(:edit,
         id: nam1.id,
         name: { name: names(:coprinus_comatus).search_name },
         vote: { value: "3" },
         reason: {
           "1" => { check: "1", notes: "Change to macro notes." },
           "2" => { check: "1", notes: "" },
           "3" => { check: "0", notes: "Add some micro notes." },
           "4" => { check: "0", notes: "" }
         })
    assert_equal(10, rolf.reload.contribution)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 0, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 0, Vote.count)

    # Make sure observation is unchanged.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check votes.
    assert_equal(4, nam1.reload.vote_sum) # 2+1 -> 3+1
    assert_equal(2, nam1.votes.length)

    # Check new reasons.
    nrs = nam1.get_reasons
    assert_equal(3, nrs.count(&:used?))
    assert_equal(1, nrs[0].num)
    assert_equal(2, nrs[1].num)
    assert_equal(3, nrs[2].num)
    assert_equal("Change to macro notes.", nrs[0].notes)
    assert_equal("", nrs[1].notes)
    assert_equal("Add some micro notes.", nrs[2].notes)
    assert_nil(nrs[3].notes)
  end

  # Rolf makes changes to name of his naming.  Shouldn't be allowed to do this
  # if Mary has voted on it.  Should clone naming, vote, and reasons.
  def test_edit_thats_being_used_change_name
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)

    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Now, Rolf makes name change to his naming (leave rest the same).
    login("rolf")
    assert_equal(10, rolf.contribution)
    post(:edit,
         id: nam1.id,
         name: { name: "Conocybe filaris" },
         vote: { value: "2" },
         reason: {
           "1" => { check: "1", notes: "Isn't it obvious?" },
           "2" => { check: "0", notes: "" },
           "3" => { check: "0", notes: "" },
           "4" => { check: "0", notes: "" }
         })
    assert_response(:redirect) # redirect indicates success
    assert_equal(12, rolf.reload.contribution)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Get new objects.
    naming = Naming.last
    vote = Vote.last

    # Make sure observation is unchanged.
    assert_equal(names(:conocybe_filaris).id, obs.reload.name_id)

    # Make sure old naming is unchanged.
    assert_equal(names(:coprinus_comatus).id, nam1.reload.name_id)
    assert_equal(1, nam1.get_reasons.count(&:used?))
    assert_equal(3, nam1.vote_sum)
    assert_equal(2, nam1.votes.length)

    # Check new naming.
    assert_equal(observations(:coprinus_comatus_obs), naming.observation)
    assert_equal(names(:conocybe_filaris).id, naming.name_id)
    assert_equal(rolf, naming.user)
    nrs = naming.get_reasons.select(&:used?)
    assert_equal(1, nrs.length)
    assert_equal(1, nrs.first.num)
    assert_equal("Isn't it obvious?", nrs.first.notes)
    assert_equal(2, naming.vote_sum)
    assert_equal(1, naming.votes.length)
    assert_equal(vote, naming.votes.first)
    assert_equal(2, vote.value)
    assert_equal(rolf, vote.user)
  end

  # ------------------------------------------------------------
  #  Test proposing new names, casting and changing votes, and
  #  setting and changing preferred_namings.
  # ------------------------------------------------------------

  # This is the standard case, nothing unusual or stressful here.
  def test_propose_naming
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Make a few assertions up front to make sure fixtures are as expected.
    assert_equal(names(:coprinus_comatus).id,
                 observations(:coprinus_comatus_obs).name_id)
    assert(namings(:coprinus_comatus_naming).user_voted?(rolf))
    assert(namings(:coprinus_comatus_naming).user_voted?(mary))
    assert_not(namings(:coprinus_comatus_naming).user_voted?(dick))
    assert(namings(:coprinus_comatus_other_naming).user_voted?(rolf))
    assert(namings(:coprinus_comatus_other_naming).user_voted?(mary))
    assert_not(namings(:coprinus_comatus_other_naming).user_voted?(dick))

    # Rolf, the owner of observations(:coprinus_comatus_obs),
    # already has a naming, which he's 80% sure of.
    # Create a new one (the genus Agaricus) that he's 100%
    # sure of.  (Mary also has a naming with two votes.)
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Agaricus" },
      vote: { value: "3" },
      reason: {
        "1" => { check: "1", notes: "Looks good to me." },
        "2" => { check: "1", notes: "" },
        "3" => { check: "0", notes: "Spore texture." },
        "4" => { check: "0", notes: "" }
      }
    }
    login("rolf")
    post(:create, params)
    assert_response(:redirect)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Make sure contribution is updated correctly.
    assert_equal(12, rolf.reload.contribution)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload

    # Get new objects.
    naming = Naming.last
    vote = Vote.last

    # Make sure observation was updated and referenced correctly.
    assert_equal(3, observations(:coprinus_comatus_obs).namings.length)
    assert_equal(names(:agaricus).id,
                 observations(:coprinus_comatus_obs).name_id)

    # Make sure naming was created correctly and referenced.
    assert_equal(observations(:coprinus_comatus_obs), naming.observation)
    assert_equal(names(:agaricus).id, naming.name_id)
    assert_equal(rolf, naming.user)
    assert_equal(3, naming.get_reasons.count(&:used?))
    assert_equal(1, naming.votes.length)

    # Make sure vote was created correctly.
    assert_equal(naming, vote.naming)
    assert_equal(rolf, vote.user)
    assert_equal(3, vote.value)

    # Make sure reasons were created correctly.
    nr1, nr2, nr3, nr4 = naming.get_reasons
    assert_equal(1, nr1.num)
    assert_equal(2, nr2.num)
    assert_equal(3, nr3.num)
    assert_equal(4, nr4.num)
    assert_equal("Looks good to me.", nr1.notes)
    assert_equal("", nr2.notes)
    assert_equal("Spore texture.", nr3.notes)
    assert_nil(nr4.notes)
    assert(nr1.used?)
    assert(nr2.used?)
    assert(nr3.used?)
    assert_not(nr4.used?)

    # Make sure a few random methods work right, too.
    assert_equal(3, naming.vote_sum)
    assert_equal(vote, naming.users_vote(rolf))
    assert(naming.user_voted?(rolf))
    assert_not(naming.user_voted?(mary))
  end

  # Now see what happens when rolf's new naming is less confident than old.
  def test_propose_uncertain_naming
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Agaricus" },
      vote: { value: "-1" }
    }
    login("rolf")
    post(:create, params)
    assert_response(:redirect)
    assert_equal(12, rolf.reload.contribution)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload
    namings(:coprinus_comatus_naming).reload

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id,
                 observations(:coprinus_comatus_obs).name_id)

    # Sure, check the votes, too, while we're at it.
    assert_equal(3, namings(:coprinus_comatus_naming).vote_sum) # 2+1 = 3
  end

  # Now see what happens when a third party proposes a name, and it wins.
  def test_propose_dicks_naming
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Dick proposes "Conocybe filaris" out of the blue.
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Conocybe filaris" },
      vote: { value: "3" }
    }
    login("dick")
    post(:create, params)
    assert_response(:redirect)
    assert_equal(12, dick.reload.contribution)
    naming = Naming.last

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload
    namings(:coprinus_comatus_naming).reload
    namings(:coprinus_comatus_other_naming).reload

    # Check votes.
    assert_equal(3, namings(:coprinus_comatus_naming).vote_sum)
    assert_equal(0, namings(:coprinus_comatus_other_naming).vote_sum)
    assert_equal(3, naming.vote_sum)
    assert_equal(2, namings(:coprinus_comatus_naming).votes.length)
    assert_equal(2, namings(:coprinus_comatus_other_naming).votes.length)
    assert_equal(1, naming.votes.length)

    # Make sure observation was updated right.
    assert_equal(names(:conocybe_filaris).id,
                 observations(:coprinus_comatus_obs).name_id)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_with_author_when_name_without_author_already_exists
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Conocybe filaris (With) Author" },
      vote: { value: "3" }
    }
    login("dick")
    post(:create, params)
    assert_redirected_to(controller: :observer, action: "show_observation",
                         id: observations(:coprinus_comatus_obs).id)
    # Dick is getting points for the naming, vote, and name change.
    assert_equal(12 + 10, dick.reload.contribution)
    naming = Naming.last
    assert_equal("Conocybe filaris", naming.name.text_name)
    assert_equal("(With) Author", naming.name.author)
    assert_equal(names(:conocybe_filaris).id, naming.name_id)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_fill_in_author
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Agaricus campestris" }
    }
    login("dick")
    post(:create, params)
    assert_response(:success) # really means failed
    params = @controller.instance_variable_get("@params")
    assert_equal("Agaricus campestris L.", params.what)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_name_with_quotes
    name = 'Foo "bar" Author'
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: name },
      approved_name: name
    }
    login("dick")
    post(:create, params)
    assert_response(:success) # really means failed
    assert(name = Name.find_by(text_name: 'Foo "bar"'))
    assert_equal('Foo "bar" Author', name.search_name)
  end

  # Rolf can destroy his naming if Mary deletes her vote on it.
  def test_rolf_destroy_rolfs_naming
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    # First delete Mary's vote for it.
    login("mary")
    obs.change_vote(nam1, Vote.delete_vote, mary)
    assert_equal(9, mary.reload.contribution)

    old_naming_id = nam1.id
    old_vote1_id = votes(:coprinus_comatus_owner_vote).id
    old_vote2_id = begin
                     votes(:coprinus_comatus_other_vote).id
                   rescue StandardError
                     nil
                   end

    login("rolf")
    get(:destroy, id: nam1.id)

    # Make sure naming and associated vote and reason were actually destroyed.
    assert_raises(ActiveRecord::RecordNotFound) do
      Naming.find(old_naming_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote1_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote2_id)
    end

    # Make sure observation was updated right.
    assert_equal(names(:agaricus_campestris).id, obs.reload.name_id)

    # Check votes. (should be no change)
    assert_equal(0, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Make sure Rolf can't destroy his naming if Dick prefers it.
  def test_rolf_destroy_rolfs_naming_when_dick_prefers_it
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    old_naming_id = nam1.id
    old_vote1_id = votes(:coprinus_comatus_owner_vote).id
    old_vote2_id = votes(:coprinus_comatus_other_vote).id

    # Make Dick prefer it.
    login("dick")
    obs.change_vote(nam1, 3, dick)
    assert_equal(11, dick.reload.contribution)

    # Have Rolf try to destroy it.
    login("rolf")
    get(:destroy, id: nam1.id)

    # Make sure naming and associated vote and reason are still there.
    assert(Naming.find(old_naming_id))
    assert(Vote.find(old_vote1_id))
    assert(Vote.find(old_vote2_id))

    # Make sure observation is unchanged.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check votes are unchanged.
    assert_equal(6, nam1.reload.vote_sum)
    assert_equal(3, nam1.votes.length)
    assert_equal(0, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  def test_enforce_imageless_rules
    params = {
      id: observations(:coprinus_comatus_obs).id,
      name: { name: "Imageless" }
    }
    login("dick")
    post(:create, params)
    assert_response(:success) # really means failed
  end

  def assert_edit
    assert_action("edit", %w[
                    _show_observation
                    _form_name_feedback
                    _form
                    _show_images
                  ])
  end
end
