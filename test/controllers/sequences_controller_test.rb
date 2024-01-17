# frozen_string_literal: true

require("test_helper")

# Controller tests for nucleotide sequences
class SequencesControllerTest < FunctionalTestCase
  ITS_BASES = \
    "gagtatgtgc acacctgccg tctttatcta tccacctgtg cacacattgt agtcttgggg" \
    "gattggttag cgacaatttt tgttgccatg tcgtcctctg gggtctatgt tatcataaac" \
    "cacttagtat gtcgtagaat gaagtatttg ggcctcagtg cctataaaac aaaatacaac" \
    "tttcagcaac ggatctcttg gctctcgcat cgatgaagaa cgcagcgaaa tgcgataagt" \
    "aatgtgaatt gcagaattca gtgaatcatc gaatctttga acgcaccttg cgctccttgg" \
    "tattccgagg agcatgcctg tttgagtgtc attaaattct caacccctcc agcttttgtt" \
    "gctggtcgtg gcttggatat gggagtgttt gctggtctca ttcgagatca gctctcctga" \
    "aatacattag tggaaccgtt tgcgatccgt caccggtgtg ataattatct acgccataga" \
    "ctgtgaacgc tctctgtatt gttctgcttc taactgtctt attaaaggac aacaatattg" \
    "aacttttgac ctcaaatcag gtaggactac ccgctgaact taagcatatc aataa"

  def obs_creator(sequence)
    sequence.observation.user
  end

  def test_index
    login
    obs = observations(:genbanked_obs)
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    results = query.results
    assert_operator(results.count, :>, 3)
    q = query.id.alphabetize

    get(:index, params: { q: q, id: results[2].id })
    assert_response(:success)
  end

  def test_index_all
    login
    get(:index, params: { flavor: :all })

    assert_response(:success)
    assert_select("#title", { text: "#{:SEQUENCE.l} Index" },
                  "index should display #{:SEQUENCES.l} Index")
    Sequence.find_each do |sequence|
      assert_select(
        "a[href *= '#{sequence_path(sequence)}']", true,
        "Sequence Index missing link to #{sequence.format_name})"
      )
    end
  end

  def test_index_by_observation
    by = "observation"

    login
    get(:index, params: { by: by })

    assert_response(:success)
    assert_displayed_title("Sequences by Observation")

    Sequence.find_each do |sequence|
      assert_select(
        "a[href *= '#{sequence_path(sequence)}']", true,
        "Sequence Index missing link to #{sequence.format_name})"
      )
    end
  end

  def test_show
    login
    # Prove sequence displayed if called with id of sequence in db
    sequence = sequences(:local_sequence)
    get(:show, params: { id: sequence.id })
    assert_response(:success)
  end

  def test_show_nonexistent_sequence
    # Prove index displayed if called with id of sequence not in db
    login
    get(:show, params: { id: 666 })
    assert_redirected_to(action: :index)
  end

  def test_show_next
    query = Query.lookup_and_save(:Sequence, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    login
    get(:show, params: { id: number1.id, q: q, flow: "next" })
    assert_redirected_to(sequence_path(number2, q: q))
  end

  def test_show_prev
    query = Query.lookup_and_save(:Sequence, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    login
    get(:show, params: { id: number2.id, q: q, flow: "prev" })
    assert_redirected_to(sequence_path(number1, q: q))
  end

  def test_new
    # choose an obs not owned by Rolf (`requires_login` will login Rolf)
    obs = observations(:minimal_unknown_obs)
    query = Query.lookup_and_save(:Sequence, :all)
    q = query.id.alphabetize
    params = { observation_id: obs.id, q: q }

    login("zero") # This user has no Observations
    get(:new, params: params)

    assert_response(:success,
                    "A user should be able to get form to add Sequence " \
                    "to someone else's Observation")
    assert_select(
      "form[action^='#{sequences_path(params: { observation_id: obs.id })}']",
      true,
      "Sequence form has missing/incorrect `observation_id`` query param"
    )
    assert_select(
      "form[action*='q=#{q}']", true,
      "Sequence form submit action missing/incorrect 'q' query param"
    )
  end

  def test_new_login_required
    # choose an obs not owned by Rolf (`requires_login` will login Rolf)
    obs = observations(:minimal_unknown_obs)
    params = { observation_id: obs.id }

    # Prove method requires login
    get(:new, params: params)
    assert_response(:redirect)
  end

  def test_create
    # Normal happy path
    # Prove logged-in user can add sequence to someone else's Observation
    obs = observations(:detailed_unknown_obs)
    locus = "ITS"
    bases = ITS_BASES
    params = {
      observation_id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }
    user = users(:zero_user) # This user has no Observations

    login(user.login)

    assert_difference("Sequence.count", 1) { post(:create, params: params) }
    sequence = Sequence.last
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(user, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(obs.show_link_args)
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_added"),
           "Failed to include Sequence added in RssLog for Observation")
  end

  def test_create_non_repo_sequence
    # Prove user can create non-repository Sequence
    obs = observations(:detailed_unknown_obs)
    owner = obs.user
    locus = "ITS"
    bases = "gagtatgtgc acacctgccg tctttatcta tccacctgtg cacacattgt agtcttgggg"
    params = {
      observation_id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }
    login(owner.login)

    assert_difference("Sequence.count", 1) { post(:create, params: params) }
    sequence = Sequence.last
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(owner, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(obs.show_link_args)
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_added"),
           "Failed to include Sequence added in RssLog for Observation")
  end

  def test_create_repo_sequence
    # Prove admin can create repository Sequence
    obs = observations(:detailed_unknown_obs)
    locus =     "ITS"
    archive =   "GenBank"
    accession = "KY366491.1"
    params = {
      observation_id: obs.id,
      sequence: { locus: locus,
                  archive: archive,
                  accession: accession }
    }
    make_admin("zero")

    assert_difference("Sequence.count", 1) { post(:create, params: params) }
    sequence = Sequence.last
    assert_equal(locus, sequence.locus)
    assert_empty(sequence.bases)
    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert_redirected_to(obs.show_link_args)
  end

  def test_create_no_login
    # Prove user must be logged in to create Sequence
    obs = observations(:detailed_unknown_obs)
    locus = "ITS"
    bases = ITS_BASES
    params = {
      observation_id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    assert_no_difference("Sequence.count") { post(:create, params: params) }
  end

  def test_create_no_locus
    # Prove that locus is required.
    obs = observations(:coprinus_comatus_obs)
    params = { observation_id: obs.id,
               sequence: { locus: "",
                           bases: "actgct" } }
    login(obs.user.login)

    assert_no_difference("Sequence.count") { post(:create, params: params) }
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_create_no_bases_or_equivalent
    # Prove that bases or archive+accession required.
    obs = observations(:coprinus_comatus_obs)
    params = { observation_id: obs.id,
               sequence: { locus: "ITS" } }
    login(obs.user.login)

    assert_no_difference("Sequence.count") { post(:create, params: params) }
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_create_archive_without_accession
    # Prove that accession required if archive present.
    obs = observations(:coprinus_comatus_obs)
    params = { observation_id: obs.id,
               sequence: { locus: "ITS", archive: "GenBank" } }
    login(obs.user.login)

    assert_no_difference("Sequence.count") { post(:create, params: params) }
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_create_accession_without_archive
    obs = observations(:coprinus_comatus_obs)
    params = { observation_id: obs.id,
               sequence: { locus: "ITS", accession: "KY133294.1" } }
    login(obs.user.login)

    assert_no_difference("Sequence.count") { post(:create, params: params) }
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_create_redirect
    obs = observations(:genbanked_obs)
    query = Query.lookup_and_save(:Sequence, :all)
    q = query.id.alphabetize
    params = { observation_id: obs.id,
               sequence: { locus: "ITS", bases: "atgc" },
               q: q }

    login(obs.user.login)

    # Prove that post keeps query params intact.
    post(:create, params: params)
    assert_redirected_to(obs.show_link_args.merge(q: q),
                         "User should go to last query after creating Sequence")
  end

  # See https://github.com/MushroomObserver/mushroom-observer/issues/1808
  def test_create_notes_with_caron
    obs = observations(:detailed_unknown_obs)
    locus = "ITS"
    bases = ITS_BASES
    caron = "ň"
    params = {
      observation_id: obs.id,
      sequence: { locus: locus,
                  bases: bases,
                  notes: caron }
    }

    login
    post(:create, params: params)

    assert_flash_success
    assert_equal(caron, Sequence.last.notes,
                 "Failed to include utf8 caron (#{caron}) in Sequence Notes")
  end

  def test_edit
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove Observation's creator can edit Sequence
    login(observer.login)
    get(:edit, params: { id: sequence.id })
    assert_response(:success)
  end

  def test_edit_by_admin
    sequence = sequences(:local_sequence)

    # Prove admin can edit Sequence of any Obs
    make_admin("zero")
    get(:edit, params: { id: sequence.id })
    assert_response(:success)
  end

  def test_edit_login_required
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user
    assert_not_equal(rolf, observer)
    assert_not_equal(rolf, sequence.user)

    # Prove method requires login
    requires_login(:edit, id: sequence.id)
  end

  def test_edit_by_other_user
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    login("zero")

    # Prove user cannot edit Sequence he didn't create for Obs he didn't create
    get(:edit, params: { id: sequence.id })
    assert_redirected_to(obs.show_link_args)
  end

  def test_edit_redirect
    obs      = observations(:genbanked_obs)
    sequence = obs.sequences[2]
    assert_operator(obs.sequences.count, :>, 3)
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession } }

    # Prove that GET passes "back" and query param through to form.
    login(obs.user.login)
    get(:edit, params: params.merge(back: obs.id, q: q))

    assert_select("form:match('action', ?)", %r{^/sequences/226969185}, true,
                  "submit action for edit Sequence form should start with " \
                  "`/sequences/<sequence.id>`")
    assert_select("form:match('action', ?)", /back=#{obs.id}/, true,
                  "submit action for edit Sequence form should include " \
                  "param to go back to Observation (back=#{obs.id})")
    assert_select("form[action*='q=#{q}']", true,
                  "submit action for edit Sequence form should include " \
                  "query param (q=#{q})")
  end

  def test_update
    sequence = sequences(:local_sequence)
    obs = sequence.observation
    observer  = obs.user
    sequencer = sequence.user

    new_locus = "new locus"
    new_bases = ITS_BASES
    new_archive = "GenBank"
    new_accession = "KT968655"
    new_notes = "New notes."
    params = { id: sequence.id,
               sequence: { locus: new_locus,
                           bases: new_bases,
                           archive: new_archive,
                           accession: new_accession,
                           notes: new_notes } }

    # Prove Observation owner creator can edit Sequence
    login(observer.login)
    patch(:update, params: params)

    assert_redirected_to(obs.show_link_args)
    assert_flash_success

    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(sequencer, sequence.user)

    sequence.reload
    assert_equal(new_locus, sequence.locus)
    assert_equal(new_bases, sequence.bases)
    assert_equal(new_archive, sequence.archive)
    assert_equal(new_accession, sequence.accession)
    assert_equal(new_notes, sequence.notes)

    obs.rss_log.reload
    assert(obs.rss_log.notes.include?("log_sequence"),
           "Failed to include Sequence change in RssLog for Observation")
  end

  def test_update_by_admin
    sequence = sequences(:local_sequence)
    obs = sequence.observation
    new_bases = ITS_BASES
    new_archive   = "GenBank"
    new_accession = "KT968655"
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: new_bases,
                           archive: new_archive,
                           accession: new_accession,
                           notes: sequence.notes } }
    # Prove admin modify
    make_admin("zero")
    patch(:update, params: params)

    sequence.reload
    assert_equal(new_bases, sequence.reload.bases)
    assert_equal(new_archive, sequence.archive)
    assert_equal(new_accession, sequence.accession)
    obs.rss_log.reload
    assert(obs.rss_log.notes.include?("log_sequence_accessioned"),
           "Failed to include Sequence accessioned in RssLog for Observation")
  end

  def test_update_locus_by_observation_creator
    sequence = sequences(:local_sequence)
    new_locus = "new_locus"
    params = { id: sequence.id,
               sequence: { locus: new_locus,
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession,
                           notes: sequence.notes } }
    # Prove Observation owner user can edit locus
    login(obs_creator(sequence).login)
    patch(:update, params: params)
    assert_equal(new_locus, sequence.reload.locus)
  end

  def test_update_not_logged_in
    sequence = sequences(:local_sequence)
    locus = "mtSSU"
    bases = ITS_BASES
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    # Prove user must be logged in to edit Sequence.
    patch(:update, params: params)
    assert_not_equal(locus, sequence.reload.locus)
  end

  def test_update_not_observation_creator
    sequence = sequences(:local_sequence)
    changed_notes = "Changed notes"
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: sequence.bases,
                           accession: sequence.accession,
                           notes: changed_notes } }
    # Prove user must have created Observation to edit Sequence.
    login("zero")
    patch(:update, params: params)

    assert_not_equal(changed_notes, sequence.reload.notes)
    assert_flash_text(:permission_denied.t)
  end

  def test_update_no_locus
    sequence = sequences(:local_sequence)
    params = { id: sequence.id,
               sequence: { locus: "",
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession,
                           notes: sequence.notes } }
    # Prove locus required.
    login(obs_creator(sequence).login)
    patch(:update, params: params)
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_update_no_bases_or_equivalent
    sequence = sequences(:local_sequence)
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: "",
                           archive: "",
                           accession: "",
                           notes: sequence.notes } }
    # Prove bases or (archive and accession) required
    login(obs_creator(sequence).login)
    patch(:update, params: params)
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_update_archive_without_accession
    sequence = sequences(:local_sequence)
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: "Genbank",
                           accession: sequence.accession,
                           notes: sequence.notes } }
    # Prove accession is required if archive present.
    login(obs_creator(sequence).login)
    patch(:update, params: params)
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_update_accession_without_archive
    sequence = sequences(:local_sequence)
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: "",
                           accession: "KT968605",
                           notes: sequence.notes } }
    # Prove archive is required if accession present.
    login(obs_creator(sequence).login)
    patch(:update, params: params)
    assert_response(:success) # response is 200 because it just reloads the form
    assert_flash_error
  end

  def test_update_redirect
    obs = observations(:genbanked_obs)
    assert_operator(obs.sequences.count, :>, 3)
    sequence = obs.sequences[2]
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession } }
    # Prove by default POST goes back to observation.
    login(obs.user.login)
    patch(:update, params: params)
    assert_redirected_to(obs.show_link_args)
  end

  def test_update_redirect_to_observation_keeps_params
    obs = observations(:genbanked_obs)
    assert_operator(obs.sequences.count, :>, 3)
    sequence = obs.sequences[2]
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession } }
    # Prove that POST keeps query param when returning to observation.
    login(obs.user.login)
    patch(:update, params: params.merge(q: q))
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_update_redirect_to_sequence_keeps_params
    obs = observations(:genbanked_obs)
    assert_operator(obs.sequences.count, :>, 3)
    sequence = obs.sequences[2]
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize
    params = { id: sequence.id,
               sequence: { locus: sequence.locus,
                           bases: sequence.bases,
                           archive: sequence.archive,
                           accession: sequence.accession } }

    # Prove that POST keeps query param when returning to sequence.
    login(obs.user.login)
    patch(:update, params: params.merge(back: "show", q: q))
    assert_redirected_to(sequence.show_link_args.merge(q: q))
  end

  def test_destroy
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove Observation owner can destroy Sequence
    login(observer.login)

    assert_difference("Sequence.count", -1) do
      delete(:destroy, params: { id: sequence.id })
    end
    assert_redirected_to(obs.show_link_args)
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_destroy_no_login
    sequence = sequences(:local_sequence)

    # Prove user must be logged in to destroy Sequence.
    assert_no_difference("Sequence.count") do
      delete(:destroy, params: { id: sequence.id })
    end
  end

  def test_destroy_by_other_user
    sequence = sequences(:local_sequence)
    obs      = sequence.observation

    # Prove user cannot destroy Sequence he didn't create for Obs he doesn't own
    login("zero")
    assert_no_difference("Sequence.count") do
      delete(:destroy, params: { id: sequence.id })
    end
    assert_redirected_to(obs.show_link_args)
    assert_flash_text(:permission_denied.t)
  end

  def test_destroy_admin
    sequence = sequences(:local_sequence)
    obs      = sequence.observation

    # Prove admin can destroy Sequence
    make_admin("zero")
    assert_difference("Sequence.count", -1) do
      delete(:destroy, params: { id: sequence.id })
    end
    assert_redirected_to(obs.show_link_args)
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_destroy_redirect
    obs   = observations(:genbanked_obs)
    seqs  = obs.sequences

    # Prove by default it goes back to observation.
    login(obs.user.login)
    delete(:destroy, params: { id: seqs[0].id })
    assert_redirected_to(obs.show_link_args)
  end

  def test_destroy_redirect_to_observation_with_query
    obs   = observations(:genbanked_obs)
    seqs  = obs.sequences
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize

    # Prove that it keeps query param intact when returning to observation.
    login(obs.user.login)
    delete(:destroy, params: { id: seqs[1].id, q: q })
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_destroy_redirect_to_index_with_query
    obs   = observations(:genbanked_obs)
    seqs  = obs.sequences
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize

    # Prove that it can return to index, too, with query intact.
    login(obs.user.login)
    delete(:destroy, params: { id: seqs[2].id, q: q, back: "index" })
    assert_redirected_to(action: :index, q: q)
  end
end
