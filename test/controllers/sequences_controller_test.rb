# frozen_string_literal: true

require "test_helper"

# Controller tests for nucleotide sequences
class SequencesControllerTest < FunctionalTestCase
  def test_index
    get(:index)
    assert(:success)
  end

  def test_search
    get(:sequence_search, pattern: Sequence.last.id)
    assert_redirected_to(sequence_path(Sequence.last))

    get(:sequence_search, pattern: "ITS")
    assert(:success)
  end

  def test_observation_index
    obs = observations(:locally_sequenced_obs)
    get(:observation_index, id: obs.id)
    assert(:success)

    obs = observations(:genbanked_obs)
    get(:observation_index, id: obs.id)
    assert(:success)
  end

  def test_index_prev_and_next
    obs = observations(:genbanked_obs)
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    results = query.results
    assert_operator(results.count, :>, 3)
    q = query.id.alphabetize

    get(:index_sequence, q: q, id: results[2].id)
    assert_response(:success)

    get(:show_next, q: q, id: results[1].id)
    assert_redirected_to(sequence_path(results[2], q: q))

    get(:show_prev, q: q, id: results[2].id)
    assert_redirected_to(sequence_path(results[1], q: q))
  end

  def test_show
    # Prove sequence displayed if called with id of sequence in db
    sequence = sequences(:local_sequence)
    get(:show, id: sequence.id)
    assert_response(:success)

    # Prove index displayed if called with id of sequence not in db
    get(:show, id: 666)
    assert_redirected_to(action: :index_sequence)
  end

  def test_new
    obs   = observations(:minimal_unknown_obs)
    owner = obs.user

    # Prove method requires login
    get(:new, id: obs.id)
    assert_redirected_to(controller: :account, action: :login)

    # Prove logged-in user can add Sequence to someone else's Observation
    login("zero")
    get(:new, id: obs.id)
    assert_response(:success)

    # Prove Observation owner can add Sequence
    login(owner.login)
    get(:new, id: obs.id)
    assert_response(:success)

    # Prove admin can add Sequence
    make_admin("zero")
    get(:new, id: obs.id)
    assert_response(:success)
  end

  def test_create
    old_count = Sequence.count
    obs   = observations(:detailed_unknown_obs)
    owner = obs.user

    locus = "ITS"
    bases = "gagtatgtgc acacctgccg tctttatcta tccacctgtg cacacattgt agtcttgggg"\
            "gattggttag cgacaatttt tgttgccatg tcgtcctctg gggtctatgt tatcataaac"\
            "cacttagtat gtcgtagaat gaagtatttg ggcctcagtg cctataaaac aaaatacaac"\
            "tttcagcaac ggatctcttg gctctcgcat cgatgaagaa cgcagcgaaa tgcgataagt"\
            "aatgtgaatt gcagaattca gtgaatcatc gaatctttga acgcaccttg cgctccttgg"\
            "tattccgagg agcatgcctg tttgagtgtc attaaattct caacccctcc agcttttgtt"\
            "gctggtcgtg gcttggatat gggagtgttt gctggtctca ttcgagatca gctctcctga"\
            "aatacattag tggaaccgtt tgcgatccgt caccggtgtg ataattatct acgccataga"\
            "ctgtgaacgc tctctgtatt gttctgcttc taactgtctt attaaaggac aacaatattg"\
            "aacttttgac ctcaaatcag gtaggactac ccgctgaact taagcatatc aataa"
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    # Prove user must be logged in to create Sequence
    post(:create, params)
    assert_equal(old_count, Sequence.count)

    # Prove logged-in user can add sequence to someone else's Observation
    user = users(:zero_user)
    login(user.login)
    post(:create, params)
    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(user, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(observation_path(obs))
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_added"),
           "Failed to include Sequence added in RssLog for Observation")

    # Prove user can create non-repository Sequence
    old_count = Sequence.count
    locus = "ITS"
    bases = "gagtatgtgc acacctgccg tctttatcta tccacctgtg cacacattgt agtcttgggg"
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    login(owner.login)
    post(:create, params)
    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(owner, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(observation_path(obs))
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_added"),
           "Failed to include Sequence added in RssLog for Observation")

    # Prove admin can create repository Sequence
    locus =     "ITS"
    archive =   "GenBank"
    accession = "KY366491.1"
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  archive: archive,
                  accession: accession }
    }
    old_count = Sequence.count
    make_admin("zero")
    post(:create, params)
    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_equal(locus, sequence.locus)
    assert_empty(sequence.bases)
    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert_redirected_to(observation_path(obs))
  end

  def test_create_wrong_parameters
    old_count = Sequence.count
    obs = observations(:coprinus_comatus_obs)
    login(obs.user.login)

    # Prove that locus is required.
    params = {
      id: obs.id,
      sequence: { locus: "",
                  bases: "actgct" }
    }
    post(:new, params)
    assert_equal(old_count, Sequence.count)
    # response is 200 because it just reloads the form
    assert_response(:success)
    assert_flash_error

    # Prove that bases or archive+accession required.
    params = {
      id: obs.id,
      sequence: { locus: "ITS" }
    }
    post(:new, params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error

    # Prove that accession required if archive present.
    params = {
      id: obs.id,
      sequence: { locus: "ITS", archive: "GenBank" }
    }
    post(:new, params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error

    # Prove that archive required if accession present.
    params = {
      id: obs.id,
      sequence: { locus: "ITS", accession: "KY133294.1" }
    }
    post(:new, params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error
  end

  def test_make_redirect
    obs = observations(:genbanked_obs)
    query = Query.lookup_and_save(:Sequence, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      sequence: { locus: "ITS", bases: "atgc" },
      q: q
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params)
    assert_select("form[action*='sequence/#{obs.id}?q=#{q}']")

    # Prove that post keeps query params intact.
    post(:new, params)
    assert_redirected_to(observation_path(obs, q: q))
  end

  def test_edit
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove method requires login
    assert_not_equal(rolf, observer)
    assert_not_equal(rolf, sequence.user)
    requires_login(:edit, id: sequence.id)

    # Prove user cannot edit Sequence he didn't create for Obs he doesn't own
    login("zero")
    get(:edit, id: sequence.id)
    assert_redirected_to(observation_path(obs))

    # Prove Observation owner can edit Sequence
    login(observer.login)
    get(:edit, id: sequence.id)
    assert_response(:success)

    # Prove admin can edit Sequence
    make_admin("zero")
    get(:edit, id: sequence.id)
    assert_response(:success)
  end

  def test_update
    sequence  = sequences(:local_sequence)
    obs       = sequence.observation
    observer  = obs.user
    sequencer = sequence.user

    locus = "mtSSU"
    bases = "gagtatgtgc acacctgccg tctttatcta tccacctgtg cacacattgt agtcttgggg"\
            "gattggttag cgacaatttt tgttgccatg tcgtcctctg gggtctatgt tatcataaac"\
            "cacttagtat gtcgtagaat gaagtatttg ggcctcagtg cctataaaac aaaatacaac"\
            "tttcagcaac ggatctcttg gctctcgcat cgatgaagaa cgcagcgaaa tgcgataagt"\
            "aatgtgaatt gcagaattca gtgaatcatc gaatctttga acgcaccttg cgctccttgg"\
            "tattccgagg agcatgcctg tttgagtgtc attaaattct caacccctcc agcttttgtt"\
            "gctggtcgtg gcttggatat gggagtgttt gctggtctca ttcgagatca gctctcctga"\
            "aatacattag tggaaccgtt tgcgatccgt caccggtgtg ataattatct acgccataga"\
            "ctgtgaacgc tctctgtatt gttctgcttc taactgtctt attaaaggac aacaatattg"\
            "aacttttgac ctcaaatcag gtaggactac ccgctgaact taagcatatc aataa"
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    # Prove user must be logged in to edit Sequence.
    post(:edit, params)
    assert_not_equal(locus, sequence.reload.locus)

    # Prove user must be owner to edit Sequence.
    login("zero")
    post(:edit, params)
    assert_not_equal(locus, sequence.reload.locus)
    assert_flash_text(:permission_denied.t)

    # Prove Observation owner user can edit Sequence
    login(observer.login)
    post(:edit, params)
    sequence.reload
    obs.rss_log.reload
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(sequencer, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(observation_path(obs))
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_updated"),
           "Failed to include Sequence updated in RssLog for Observation")

    # Prove admin can accession Sequence
    archive   = "GenBank"
    accession = "KT968655"
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases,
                  archive: archive,
                  accession: accession }
    }
    make_admin("zero")
    post(:edit, params)
    sequence.reload
    obs.rss_log.reload
    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert(obs.rss_log.notes.include?("log_sequence_accessioned"),
           "Failed to include Sequence accessioned in RssLog for Observation")

    # Prove Observation owner user can edit locus
    locus  = "ITS"
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases,
                  archive: archive,
                  accession: accession }
    }
    post(:edit, params)
    assert_equal(locus, sequence.reload.locus)

    # Prove locus required.
    params = {
      id: sequence.id,
      sequence: { locus: "",
                  bases: bases,
                  archive: archive,
                  accession: accession }
    }
    post(:edit, params)
    # response is 200 because it just reloads the form
    assert_response(:success)
    assert_flash_error

    # Prove bases or archive+accession required.
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: "",
                  archive: "",
                  accession: "" }
    }
    post(:edit, params)
    assert_response(:success)
    assert_flash_error

    # Prove accession required if archive present.
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases,
                  archive: archive,
                  accession: "" }
    }
    post(:edit, params)
    assert_response(:success)
    assert_flash_error

    # Prove archive required if accession present.
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases,
                  archive: "",
                  accession: accession }
    }
    post(:edit, params)
    assert_response(:success)
    assert_flash_error
  end

  def test_change_redirect
    obs      = observations(:genbanked_obs)
    sequence = obs.sequences[2]
    assert_operator(obs.sequences.count, :>, 3)
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize
    login(obs.user.login)
    params = {
      id: sequence.id,
      sequence: { locus: sequence.locus,
                  bases: sequence.bases,
                  archive: sequence.archive,
                  accession: sequence.accession }
    }

    # Prove that GET passes "back" and query param through to form.
    get(:edit, params.merge(back: "foo", q: q))
    assert_select("form[action*='sequence/#{sequence.id}?back=foo&q=#{q}']")

    # Prove by default POST goes back to observation.
    post(:edit, params)
    assert_redirected_to(observation_path(obs))

    # Prove that POST keeps query param when returning to observation.
    post(:edit, params.merge(q: q))
    assert_redirected_to(observation_path(obs, q: q))

    # Prove that POST can return to show, too, with query intact.
    post(:edit, params.merge(back: "show", q: q))
    assert_redirected_to(sequence_path(sequence, q: q))
  end

  def test_destroy
    old_count = Sequence.count
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove user must be logged in to destroy Sequence.
    post(:destroy, id: sequence.id)
    assert_equal(old_count, Sequence.count)

    # Prove user cannot destroy Sequence he didn't create for Obs he doesn't own
    login("zero")
    post(:destroy, id: sequence.id)
    assert_equal(old_count, Sequence.count)
    assert_redirected_to(observation_path(obs))
    assert_flash_text(:permission_denied.t)

    # Prove Observation owner can destroy Sequence
    login(observer.login)
    post(:destroy, id: sequence.id)
    assert_equal(old_count - 1, Sequence.count)
    assert_redirected_to(observation_path(obs))
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_destroy_admin
    old_count = Sequence.count
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove admin can destroy Sequence
    make_admin("zero")
    post(:destroy, id: sequence.id)
    assert_equal(old_count - 1, Sequence.count)
    assert_redirected_to(observation_path(obs))
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_destroy_redirect
    obs   = observations(:genbanked_obs)
    seqs  = obs.sequences
    query = Query.lookup_and_save(:Sequence, :for_observation, observation: obs)
    q     = query.id.alphabetize
    login(obs.user.login)

    # Prove by default it goes back to observation.
    post(:destroy, id: seqs[0].id)
    assert_redirected_to(observation_path(obs))

    # Prove that it keeps query param intact when returning to observation.
    post(:destroy, id: seqs[1].id, q: q)
    assert_redirected_to(observation_path(obs, q: q))

    # Prove that it can return to index, too, with query intact.
    post(:destroy, id: seqs[2].id, q: q, back: "index")
    assert_redirected_to(action: :index_sequence, q: q)
  end
end
