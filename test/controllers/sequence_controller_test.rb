require "test_helper"

# Controller tests for nucleotide sequences
class SequenceControllerTest < FunctionalTestCase
  def test_add_sequence_get
    # obs not owned by Rolf (because `requires_login` will login Rolf)
    obs   = observations(:minimal_unknown_obs)
    owner = obs.user

    # Prove method requires login
    requires_login(:add_sequence, id: obs.id)

    # Prove user cannot add Sequence to Observation he doesn't own
    login(users(:zero_user).login)
    get(:add_sequence, id: observations(:minimal_unknown_obs).id)
    assert_redirected_to(controller: :observer, action: :show_observation)

    # Prove Observation owner can add Sequence
    login(owner.login)
    get(:add_sequence, id: obs.id)
    assert_response(:success)
  end

  def test_add_sequence_post_happy_paths
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

    # Prove authorized user can create non-repository Sequence
    old_count = Sequence.count
    login(owner.login)
    post(:add_sequence, params)
    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_equal(obs, sequence.observation)
    assert_equal(owner, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(controller: :observer, action: :show_observation)
    assert(obs.rss_log.notes.include?("log_sequence_added"),
           "Failed to include Sequence added in RssLog for Observation")

    # Prove authorized user can create repository Sequence
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
    post(:add_sequence, params)
    assert_equal(old_count + 1, Sequence.count)
    sequence = Sequence.last
    assert_equal(locus, sequence.locus)
    assert_empty(sequence.bases)
    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert_redirected_to(controller: :observer, action: :show_observation)
  end

  def test_add_sequence_post_unhappy_paths
    obs   = observations(:coprinus_comatus_obs)
    owner = obs.user
    locus = "ITS"
    bases = "aaccggtt"
    params = {
      id: obs.id,
      sequence: { locus: locus,
                  bases: bases }
    }

    # Prove unauthorized User cannot add Sequence
    old_count = Sequence.count
    login(users(:zero_user).login)

    post(:add_sequence, params)
    assert_flash_text(:permission_denied.l)
    assert_equal(old_count, Sequence.count)
    assert_empty(obs.sequences)
    assert_redirected_to(controller: :observer, action: :show_observation)

    # Prove returned to form if parameters invalid
    params = {
      id: obs.id,
      sequence: { locus: "",
                  bases: bases }
    }
    old_count = Sequence.count
    login(owner.login)

    post(:add_sequence, params)
    assert_equal(old_count, Sequence.count)
    assert_empty(obs.sequences)
    # response is 200 because it just reloads the form
    assert_response(:success)
  end

  def test_edit_sequence_get
    sequence  = sequences(:local_sequence)
    obs       = sequence.observation
    observer  = obs.user

    # Prove method requires login
    requires_login(:edit_sequence, id: sequence.id)

    # Prove user cannot edit Sequence he didn't create for Obs he doesn't own
    login(users(:zero_user).login)
    get(:edit_sequence, id: sequence.id)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)

    # Prove Observation owner can edit Sequence
    login(observer.login)
    get(:edit_sequence, id: sequence.id)
    assert_response(:success)
  end

  def test_edit_sequence_post
    sequence  = sequences(:local_sequence)
    obs       = sequence.observation
    observer  = obs.user
    sequencer = sequence.user
    locus = "LSU"
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

    # Prove Observation owner user can edit Sequence
    login(observer.login)
    post(:edit_sequence, params)
    sequence.reload
    obs.rss_log.reload

    assert_equal(obs, sequence.observation)
    assert_equal(sequencer, sequence.user)
    assert_equal(locus, sequence.locus)
    assert_equal(bases, sequence.bases)
    assert_empty(sequence.archive)
    assert_empty(sequence.accession)
    assert_redirected_to(controller: :sequence, action: :show_sequence,
                         id: sequence.id)
    assert(obs.rss_log.notes.include?("log_sequence_updated"),
           "Failed to include Sequence updated in RssLog for Observation")

    # Prove Observation owner user can accession Sequence
    archive   = "GenBank"
    accession = "KT968655"
    params = {
      id: sequence.id,
      sequence:  { locus:     locus,
                   bases:     bases,
                   archive:   archive,
                   accession: accession }
    }

    post(:edit_sequence, params)
    sequence.reload
    obs.rss_log.reload

    assert_equal(archive, sequence.archive)
    assert_equal(accession, sequence.accession)
    assert(obs.rss_log.notes.include?("log_sequence_accessioned"),
           "Failed to include Sequence accessioned in RssLog for Observation")
  end

  def test_show_sequence
    # Prove sequence displayed if called with id of sequence in db
    sequence = sequences(:local_sequence)
    get(:show_sequence, id: sequence.id)
    assert_response(:success)

    # Prove index displayed if called with id of sequence not in db
    get(:show_sequence, id: 666)
    assert_redirected_to(action: :index_sequence)
  end

  def test_destroy_sequence
    sequence  = sequences(:local_sequence)
    obs       = sequence.observation
    observer  = obs.user

    # Prove user cannot destroy Sequence he didn't create for Obs he doesn't own
    old_count = Sequence.count
    login(users(:zero_user).login)
    post(:destroy_sequence, id: sequence.id)

    assert_equal(old_count, Sequence.count)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)

    # Prove Observation owner can destroy Sequence
    login(observer.login)
    post(:destroy_sequence, id: sequence.id)
    assert_equal(old_count - 1, Sequence.count)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)
    assert(obs.rss_log.notes.include?("log_sequence_destroy"),
           "Failed to include Sequence destroyed in RssLog for Observation")
  end

  def test_index_sequence
    get(:index_sequence)
    assert(:success)
  end
end
