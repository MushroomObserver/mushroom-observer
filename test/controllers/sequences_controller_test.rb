# frozen_string_literal: true

require("test_helper")

# Controller tests for nucleotide sequences
class SequencesControllerTest < FunctionalTestCase
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
    assert_select("#title-caption", { text: "#{:SEQUENCE.l} Index" },
                  "index should display #{:SEQUENCES.l} Index")
    Sequence.find_each do |sequence|
      assert_select(
        "a[href *= '#{sequence_path(sequence)}']", true,
        "Sequence Index missing link to #{sequence.format_name})"
      )
    end
  end

  def test_search_pattern_id
    login
    get(:index, params: { pattern: Sequence.last.id })
    assert_redirected_to(Sequence.last.show_link_args)
  end

  def test_search_pattern_text
    login
    get(:index, params: { pattern: "ITS" })
    assert(:success)
  end

  def test_observation_index
    login
    obs = observations(:genbanked_obs)
    assert(obs.sequences.size.positive?,
           "Use a fixture withn >= 1 sequence")

    get(:index, params: { flavor: :observation, id: obs.id })

    assert_response(:success)
    obs.sequences.each do |sequence|
      assert_select("a[href ^= '#{sequence_path(sequence.id)}']",
                    { count: 1 },
                    "Page missing a link to Sequence")
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
    # Prove logged-in user can add Sequence to someone else's Observation
    login("zero") # This user has no Observations

    get(:new, params: { id: obs.id })
    assert_response(:success)
  end

  def test_new_login_required
    # choose an obs not owned by Rolf (`requires_login` will login Rolf)
    obs = observations(:minimal_unknown_obs)

    # Prove method requires login
    requires_login(:new, id: obs.id)
  end

  def test_create
    # Normal happy path
    # Prove logged-in user can add sequence to someone else's Observation
    obs = observations(:detailed_unknown_obs)
    locus = "ITS"
    bases = \
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
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }
    user = users(:zero_user) # This user has no Observations
    old_count = Sequence.count

    login(user.login)
    post(:create, params: params)

    assert_equal(old_count + 1, Sequence.count)
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
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }
    old_count = Sequence.count

    login(owner.login)
    post(:create, params: params)

    assert_equal(old_count + 1, Sequence.count)
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
      id: obs.id,
      sequence: { locus: locus,
                  archive: archive,
                  accession: accession }
    }
    old_count = Sequence.count

    make_admin("zero")
    post(:create, params: params)

    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_equal(locus, sequence.locus)
    assert_empty(sequence.bases)
    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert_redirected_to(obs.show_link_args)
  end

  def test_create_no_login
    # Prove user must be logged in to create Sequence
    old_count = Sequence.count
    obs = observations(:detailed_unknown_obs)

    locus = "ITS"
    bases = \
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
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    post(:create, params: params)
    assert_equal(old_count, Sequence.count)
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
    post(:create, params: params)
    assert_equal(old_count, Sequence.count)
    # response is 200 because it just reloads the form
    assert_response(:success)
    assert_flash_error

    # Prove that bases or archive+accession required.
    params = {
      id: obs.id,
      sequence: { locus: "ITS" }
    }
    post(:create, params: params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error

    # Prove that accession required if archive present.
    params = {
      id: obs.id,
      sequence: { locus: "ITS", archive: "GenBank" }
    }
    post(:create, params: params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error

    # Prove that archive required if accession present.
    params = {
      id: obs.id,
      sequence: { locus: "ITS", accession: "KY133294.1" }
    }
    post(:create, params: params)
    assert_equal(old_count, Sequence.count)
    assert_response(:success)
    assert_flash_error
  end

  def test_create_redirect
    obs = observations(:genbanked_obs)
    query = Query.lookup_and_save(:Sequence, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      sequence: { locus: "ITS", bases: "atgc" },
      q: q
    }

    login(obs.user.login)
    get(:new, params: params)
    assert_select("form[action*='?q=#{q}']", true,
                  "Sequence form submit action missing 'q' param")

    # Prove that post keeps query params intact.
    post(:create, params: params)
    assert_redirected_to(obs.show_link_args.merge(q: q))
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
    get(:edit, params: { id: sequence.id })
    assert_redirected_to(obs.show_link_args)

    # Prove Observation owner can edit Sequence
    login(observer.login)
    get(:edit, params: { id: sequence.id })
    assert_response(:success)

    # Prove admin can edit Sequence
    make_admin("zero")
    get(:edit, params: { id: sequence.id })
    assert_response(:success)
  end

  def test_update
    sequence  = sequences(:local_sequence)
    obs       = sequence.observation
    observer  = obs.user
    sequencer = sequence.user

    locus = "mtSSU"
    bases = \
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
    params = {
      id: sequence.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    # Prove user must be logged in to edit Sequence.
    patch(:update, params: params)
    assert_not_equal(locus, sequence.reload.locus)

    # Prove user must be owner to edit Sequence.
    login("zero")
    patch(:update, params: params)
    assert_not_equal(locus, sequence.reload.locus)
    assert_flash_text(:permission_denied.t)

    # Prove Observation owner user can edit Sequence
    login(observer.login)
    patch(:update, params: params)
    sequence.reload
    obs.rss_log.reload
    assert_objs_equal(obs, sequence.observation)
    assert_users_equal(sequencer, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(obs.show_link_args)
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
    patch(:update, params: params)
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
    patch(:update, params: params)
    assert_equal(locus, sequence.reload.locus)

    # Prove locus required.
    params = {
      id: sequence.id,
      sequence: { locus: "",
                  bases: bases,
                  archive: archive,
                  accession: accession }
    }
    patch(:update, params: params)
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
    patch(:update, params: params)
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
    patch(:update, params: params)
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
    patch(:update, params: params)
    assert_response(:success)
    assert_flash_error
  end

  def test_edit_redirect
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
    get(:edit, params: params.merge(back: "foo", q: q))
    assert_select("form[action*='sequences/#{sequence.id}?back=foo&q=#{q}']")

    # Prove by default POST goes back to observation.
    patch(:update, params: params)
    assert_redirected_to(obs.show_link_args)

    # Prove that POST keeps query param when returning to observation.
    patch(:update, params: params.merge(q: q))
    assert_redirected_to(obs.show_link_args.merge(q: q))

    # Prove that POST can return to show_sequence, too, with query intact.
    patch(:update, params: params.merge(back: "show", q: q))
    assert_redirected_to(sequence.show_link_args.merge(q: q))
  end

  def test_destroy
    old_count = Sequence.count
    sequence = sequences(:local_sequence)
    obs      = sequence.observation
    observer = obs.user

    # Prove user must be logged in to destroy Sequence.
    delete(:destroy, params: { id: sequence.id })
    assert_equal(old_count, Sequence.count)

    # Prove user cannot destroy Sequence he didn't create for Obs he doesn't own
    login("zero")
    delete(:destroy, params: { id: sequence.id })
    assert_equal(old_count, Sequence.count)
    assert_redirected_to(obs.show_link_args)
    assert_flash_text(:permission_denied.t)

    # Prove Observation owner can destroy Sequence
    login(observer.login)
    delete(:destroy, params: { id: sequence.id })
    assert_equal(old_count - 1, Sequence.count)
    assert_redirected_to(obs.show_link_args)
    assert_flash_success
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_destroy_admin
    old_count = Sequence.count
    sequence = sequences(:local_sequence)
    obs      = sequence.observation

    # Prove admin can destroy Sequence
    make_admin("zero")
    delete(:destroy, params: { id: sequence.id })
    assert_equal(old_count - 1, Sequence.count)
    assert_redirected_to(obs.show_link_args)
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
    delete(:destroy, params: { id: seqs[0].id })
    assert_redirected_to(obs.show_link_args)

    # Prove that it keeps query param intact when returning to observation.
    delete(:destroy, params: { id: seqs[1].id, q: q })
    assert_redirected_to(obs.show_link_args.merge(q: q))

    # Prove that it can return to index, too, with query intact.
    delete(:destroy, params: { id: seqs[2].id, q: q, back: "index" })
    assert_redirected_to(action: :index, q: q)
  end
end
