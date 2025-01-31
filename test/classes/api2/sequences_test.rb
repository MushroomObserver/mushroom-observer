# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::SequencesTest < UnitTestCase
  include API2Extensions

  def test_basic_sequence_get
    do_basic_get_test(Sequence)
  end

  # ------------------------------
  #  :section: Sequence Requests
  # ------------------------------

  def test_getting_sequences
    params = { method: :get, action: :sequence }

    seq = Sequence.all.sample
    assert_api_pass(params.merge(id: seq.id))
    assert_api_results([seq])

    seqs = Sequence.created_on("2017-01-01")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(created_at: "2017-01-01"))
    assert_api_results(seqs)

    seqs = Sequence.where(
      Sequence[:updated_at].year.eq(2017).and(Sequence[:updated_at].month.eq(2))
    )
    assert_not_empty(seqs)
    assert_api_pass(params.merge(updated_at: "2017-02"))
    assert_api_results(seqs)

    obs = observations(:locally_sequenced_obs)
    obs.update!(user: mary)
    obs.sequences.each { |s| s.update!(user: mary) }
    seqs = Sequence.where(user: mary)
    assert_not_empty(seqs)
    assert_api_pass(params.merge(user: "mary"))
    assert_api_results(seqs)

    seqs = Sequence.where(locus: %w[ITS1F ITS4 ITS5])
    assert_not_empty(seqs)
    assert_api_pass(params.merge(locus: "its1f,its4,its5"))
    assert_api_results(seqs)

    seqs = Sequence.where(archive: %w[GenBank UNITE])
    assert_not_empty(seqs)
    assert_api_pass(params.merge(archive: "genbank,unite"))
    assert_api_results(seqs)

    seqs = Sequence.where(accession: "KT968605")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(accession: "KT968605"))
    assert_api_results(seqs)

    seqs = Sequence.where(Sequence[:locus].matches("%its%"))
    assert_not_empty(seqs)
    assert_api_pass(params.merge(locus_has: "ITS"))
    assert_api_results(seqs)

    seqs = Sequence.where(Sequence[:accession].matches("%kt%"))
    assert_not_empty(seqs)
    assert_api_pass(params.merge(accession_has: "KT"))
    assert_api_results(seqs)

    seqs = Sequence.where(Sequence[:notes].matches("%formatted%"))
    assert_not_empty(seqs)
    assert_api_pass(params.merge(notes_has: "formatted"))
    assert_api_results(seqs)

    # Make sure all observations have at least one sequence for the rest.
    Observation.find_each do |obs2|
      next if obs2.sequences.any?

      Sequence.create!(observation: obs2, user: obs2.user, locus: "ITS1F",
                       archive: "GenBank", accession: "MO#{obs2.id}")
    end

    obses = Observation.where(
      (Observation[:when].year >= 2012).and(Observation[:when].year <= 2014)
    )
    assert_not_empty(obses)
    assert_api_pass(params.merge(obs_date: "2012-2014"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(user: dick)
    assert_not_empty(obses)
    assert_api_pass(params.merge(observer: "dick"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.without_name
    assert_not_empty(obses)
    assert_api_pass(params.merge(name: "Fungi"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    Observation.create!(user: rolf, when: Time.zone.now,
                        where: locations(:burbank),
                        name: names(:lactarius_alpinus))
    Observation.create!(user: rolf, when: Time.zone.now,
                        where: locations(:burbank),
                        name: names(:lactarius_alpigenes))
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    assert(obses.length > 1)
    assert_api_pass(params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(obses.map(&:sequences).flatten)
    assert_api_pass(
      params.merge(name: "Lactarius alpinus", include_synonyms: "yes")
    )
    assert_api_results(obses.map(&:sequences).flatten)

    assert_blank(
      Observation.where(text_name: "Agaricus"),
      "Tests won't work if there's already an Observation for genus Agaricus"
    )
    ssp_obs = Observation.of_names_like("Agaricus")
    assert(ssp_obs.length > 1)
    agaricus = Name.where(text_name: "Agaricus").first # (an existing autonym)
    agaricus_obs = Observation.create(name: agaricus, user: rolf)
    agaricus_sequence = Sequence.create(
      observation: agaricus_obs, user: rolf, locus: "ITS", bases: "ACGT"
    )
    ssp_sequences = ssp_obs.map(&:sequences).flatten.sort_by(&:id)
    assert_api_pass(params.merge(children_of: "Agaricus"))
    assert_api_results(ssp_sequences)
    assert_api_pass(params.merge(name: "Agaricus", include_subtaxa: "yes"))
    assert_api_results(ssp_sequences << agaricus_sequence)

    obses = Observation.at_locations(locations(:burbank))
    assert(obses.length > 1)
    assert_api_pass(params.merge(location: 'Burbank\, California\, USA'))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = HerbariumRecord.where(herbarium: herbaria(:nybg_herbarium)).
            map(&:observations).flatten.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium: "The New York Botanical Garden"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    rec = herbarium_records(:interesting_unknown)
    obses = rec.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium_record: rec.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    proj = projects(:one_genus_two_species_project)
    obses = proj.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(project: proj.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    spl = species_lists(:one_genus_three_species_list)
    obses = spl.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(species_list: spl.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(vote_cache: 3)
    assert(obses.length > 1)
    assert_api_pass(params.merge(confidence: "3.0"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(lat: [34..35], lng: [-119..-118])
    locs = Location.in_box(north: 35, south: 34, east: -118, west: -119)

    obses = (obses + locs.map(&:observations)).flatten.uniq.sort_by(&:id)
    assert_not_empty(obses)
    assert_api_fail(params.merge(south: 34, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, east: -118))
    assert_api_pass(params.merge(north: 35, south: 34, east: -118, west: -119))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.not_collection_location
    assert(obses.length > 1)
    assert_api_pass(params.merge(is_collection_location: "no"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    with    = Observation.with_images
    without = Observation.without_images
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_images: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_images: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    names = Name.with_rank_at_or_below_genus
    with = Observation.where(name: names)
    without = Observation.where.not(name: names)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_name: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_name: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    with    = Observation.with_specimen
    without = Observation.without_specimen
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_specimen: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_specimen: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    with = Observation.with_notes
    without = Observation.without_notes
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_obs_notes: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_obs_notes: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.notes_contain(":substrate:").
            reject { |o| o.notes[:substrate].blank? }
    assert(obses.length > 1)
    assert_api_pass(params.merge(has_notes_field: "substrate"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.notes_contain("orphan")
    assert(obses.length > 1)
    assert_api_pass(params.merge(obs_notes_has: "orphan"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))
  end

  def test_creating_sequences
    rolfs_obs  = observations(:coprinus_comatus_obs)
    marys_obs  = observations(:detailed_unknown_obs)
    @obs       = rolfs_obs
    @locus     = "ITS1F"
    @bases     = "gattcgatcgatcgatcatctcgatgcatgactctcgatgcatctac"
    @archive   = "UNITE"
    @accession = "NY123456"
    @notes     = "these are notes"
    @user      = rolf
    params = {
      method: :post,
      action: :sequence,
      api_key: @api_key.key,
      observation: rolfs_obs.id,
      locus: @locus,
      bases: @bases,
      archive: @archive,
      accession: @accession,
      notes: @notes
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:locus))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:archive))
    assert_api_fail(params.except(:accession))
    assert_api_pass(params.merge(observation: marys_obs.id))
    assert_api_fail(params.merge(archive: "bogus"))
    assert_api_fail(params.merge(bases: "funky stuff!"))
    assert_api_pass(params)
    assert_last_sequence_correct
    assert_api_fail(params)
    @accession += "b"
    @bases     += "b"
    assert_api_fail(params.merge(accession: @accession))
    assert_api_fail(params.merge(bases: @bases))
    assert_api_pass(params.merge(accession: @accession, bases: @bases))
    assert_last_sequence_correct

    @locus     = "MSU1"
    @bases     = "gtctatcagtcgacagcatgcgccactgctaacacg"
    @archive   = nil
    @accession = nil
    @notes     = nil
    params = {
      method: :post,
      action: :sequence,
      api_key: @api_key.key,
      observation: rolfs_obs.id
    }
    assert_api_fail(params)
    assert_api_fail(params.merge(locus: @locus))
    assert_api_pass(params.merge(locus: @locus, bases: @bases))
    assert_last_sequence_correct

    @locus     = "LSU"
    @bases     = nil
    @archive   = "GenBank"
    @accession = "AR09876"
    @notes     = nil
    params = {
      method: :post,
      action: :sequence,
      api_key: @api_key.key,
      observation: rolfs_obs.id
    }
    assert_api_fail(params)
    assert_api_fail(params.merge(locus: @locus))
    assert_api_fail(params.merge(locus: @locus, archive: @archive))
    assert_api_pass(params.merge(locus: @locus, archive: @archive,
                                 accession: @accession))
    assert_last_sequence_correct
  end

  def test_patching_sequences
    seq        = sequences(:alternate_archive)
    @user      = dick
    @obs       = seq.observation
    @locus     = "NEWITS"
    @bases     = "gtac"
    @archive   = "GenBank"
    @accession = "XX123456"
    @notes     = "new notes"
    params = {
      method: :patch,
      action: :sequence,
      api_key: @api_key.key,
      id: seq.id,
      set_locus: @locus,
      set_bases: @bases,
      set_archive: @archive,
      set_accession: @accession,
      set_notes: @notes
    }
    assert_api_fail(params)
    @api_key.update!(user: dick)
    assert_api_fail(params.merge(set_locus: ""))
    assert_api_fail(params.merge(set_archive: "bogus"))
    assert_api_fail(params.merge(set_archive: ""))
    assert_api_fail(params.merge(set_accession: ""))
    assert_api_pass(params)
    assert_last_sequence_correct(seq.reload)
  end

  def test_deleting_sequences
    seq = dick.sequences.sample
    params = {
      method: :delete,
      action: :sequence,
      api_key: @api_key.key,
      id: seq.id
    }
    assert_api_fail(params)
    assert_not_nil(Sequence.safe_find(seq.id))
    @api_key.update!(user: dick)
    assert_api_pass(params)
    assert_nil(Sequence.safe_find(seq.id))
  end
end
