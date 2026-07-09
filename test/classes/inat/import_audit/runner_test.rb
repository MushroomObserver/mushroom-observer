# frozen_string_literal: true

require("test_helper")
require("tempfile")

module Inat::ImportAudit
  # Tests the orchestration: selection, streaming, CSV output, summary.
  # The fetcher is injected so these don't hit the iNat API.
  class RunnerTest < UnitTestCase
    def test_ids_run_writes_row_and_summary
      obs = observations(:imported_inat_obs)
      io = StringIO.new
      audit(ids: [obs.id], io: io,
            fetcher: stub_fetcher(inat_ext_id(obs) => inat_raw)) do |path|
        rows = CSV.read(path, headers: true)
        assert_equal(1, rows.size)
        assert_equal(obs.id.to_s, rows.first["mo_id"])
        assert_equal("ok", rows.first["inat_status"])
      end
      assert_match(/Summary of 1 observation/, io.string)
      assert_match(/iNat source found:\s+1/, io.string)
    end

    def test_full_run_streams_the_relation_path
      obs = observations(:imported_inat_obs)
      audit(sample: 0,
            fetcher: stub_fetcher(inat_ext_id(obs) => inat_raw)) do |path|
        rows = CSV.read(path, headers: true)
        assert_operator(rows.size, :>=, 1)
        assert(rows.any? { |r| r["mo_id"] == obs.id.to_s })
      end
    end

    def test_not_found_when_source_absent_from_results
      obs = observations(:imported_inat_obs)
      audit(ids: [obs.id], fetcher: stub_fetcher({})) do |path|
        row = CSV.read(path, headers: true).first
        assert_equal("not_found", row["inat_status"])
      end
    end

    def test_fetch_error_when_batch_fails
      obs = observations(:imported_inat_obs)
      audit(ids: [obs.id], fetcher: failing_fetcher) do |path|
        row = CSV.read(path, headers: true).first
        assert_equal("fetch_error", row["inat_status"])
      end
    end

    def test_sample_path_uses_seeded_random
      io = StringIO.new
      audit(sample: 5, seed: 1, io: io, fetcher: stub_fetcher({})) do |path|
        assert_path_exists(path)
      end
      assert_match(/seed=1/, io.string)
    end

    def test_raises_without_inaturalist_site
      external_sites(:inaturalist).update!(name: "Renamed Site")
      assert_raises(RuntimeError) { Runner.new(ids: []) }
    end

    def test_fetcher_defaults_to_a_real_fetcher
      runner = Runner.new(ids: [], io: StringIO.new)
      assert_instance_of(Inat::ObsFetcher, runner.send(:fetcher))
    end

    private

    # The iNat observation id from the obs's import ExternalLink (#4299).
    def inat_ext_id(obs)
      obs.import_link.external_id
    end

    def audit(fetcher:, **)
      file = Tempfile.new(["audit", ".csv"])
      runner = Runner.new(io: StringIO.new, out: file.path, **)
      runner.define_singleton_method(:fetcher) { fetcher }
      runner.run
      yield(file.path)
    ensure
      file&.close!
    end

    def stub_fetcher(by_external_id)
      by_id = by_external_id.transform_keys(&:to_s)
      fetcher = Object.new
      fetcher.define_singleton_method(:fetch_batch) { |_ids| [by_id, false] }
      fetcher
    end

    def failing_fetcher
      fetcher = Object.new
      fetcher.define_singleton_method(:fetch_batch) { |_ids| [{}, true] }
      fetcher
    end

    def inat_raw
      { taxon: { name: "Boletus", rank: "species", ancestor_ids: [] },
        description: "", user: { login: "joe" }, observation_photos: [] }
    end
  end
end
