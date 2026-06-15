# frozen_string_literal: true

require "csv"

module Inat::ImportAudit
  # Orchestrates the read-only import audit: selects iNat-imported
  # observations and streams them page-by-page - fetch a batch, build its
  # rows, append to the CSV, log progress - so memory stays bounded, the CSV
  # survives a crash, and a live rate/ETA is visible. No writes to MO or iNat.
  class Runner
    PAGE = Fetcher::PAGE_SIZE

    # Summary flags counted by truthiness/presence (booleans + delta strings).
    TALLY_FLAGS = [:has_delta, :delta_note_keys, :collector_differs,
                   :ambiguous, :other_residual].freeze

    def initialize(sample: 10, ids: nil, seed: nil,
                   out: "inat_import_audit.csv", io: $stdout)
      @sample = sample
      @explicit_ids = ids
      @seed = seed || rand(1_000_000)
      @out = out
      @io = io
      @source = Source.find_by(name: Source::INATURALIST_NAME)
      raise("No iNaturalist Source row in this database") unless @source
    end

    def run
      scope = select_observations
      @io.puts("Auditing #{count(scope)} observation(s) " \
               "(seed=#{@seed}) -> #{@out}")
      @builder = RowBuilder.new(source: @source)
      @tally = Hash.new(0)
      @total = 0
      @started = clock
      CSV.open(@out, "w") { |csv| stream(scope, csv) }
      print_summary
    end

    private

    # --- Selection ---

    def select_observations
      scope = Observation.where(source_id: @source.id).
              where.not(external_id: nil).
              includes(:collector_user, :images, :rss_log)
      return scope.where(id: @explicit_ids.map(&:to_i)).to_a if @explicit_ids
      return scope.order(:id) if @sample.zero? # full run: stream a relation

      scope.order(Arel.sql("RAND(#{@seed.to_i})")).limit(@sample).to_a
    end

    def count(scope)
      scope.is_a?(Array) ? scope.size : scope.count
    end

    # --- Streaming ---

    def stream(scope, csv)
      @headers = nil
      each_batch(scope) do |batch, idx, batches|
        sleep(Fetcher::INTER_PAGE_SLEEP) if idx.positive?
        write_batch(csv, batch)
        csv.flush
        log_progress(idx + 1, batches)
      end
    end

    def each_batch(scope)
      batches = (count(scope) / PAGE.to_f).ceil
      if scope.is_a?(Array)
        scope.each_slice(PAGE).with_index do |batch, i|
          yield(batch, i, batches)
        end
      else
        scope.in_batches(of: PAGE).each_with_index do |rel, i|
          yield(rel.to_a, i, batches)
        end
      end
    end

    # Memoized so tests can inject a stub via a singleton override.
    def fetcher
      @fetcher ||= Fetcher.new
    end

    def write_batch(csv, batch)
      by_id, failed = fetcher.fetch_batch(batch.map(&:external_id))
      batch.each do |obs|
        row = @builder.call(obs, by_id[obs.external_id.to_s],
                            fetch_failed: failed)
        write_row(csv, row)
        tally_row(row)
        @total += 1
      end
    end

    def write_row(csv, row)
      unless @headers
        @headers = row.keys
        csv << @headers
      end
      csv << @headers.map { |key| row[key] }
    end

    # --- Tally + progress ---

    def tally_row(row)
      @tally[row[:inat_status].to_sym] += 1
      @tally[:no_snapshot] += 1 unless row[:snapshot_present]
      @tally[:image_mismatch] += 1 if row[:images_count_match] == false
      TALLY_FLAGS.each { |key| @tally[key] += 1 if row[key].present? }
    end

    def log_progress(done, batches)
      elapsed = clock - @started
      left = done.positive? ? (batches - done) * (elapsed / done) : 0
      @io.puts(format("  page %d/%d | %d rows | delta %d, ambiguous %d " \
                      "| %ds elapsed, ~%ds left",
                      done, batches, @total, @tally[:has_delta],
                      @tally[:ambiguous], elapsed, left))
      @io.flush
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # --- Summary ---

    def print_summary
      elapsed = (clock - @started).round
      @io.puts("\nWrote #{@out} (#{@total} rows in #{elapsed}s)")
      @io.puts("\nSummary of #{@total} observation(s):")
      summary_lines.each { |line| @io.puts("  #{line}") }
    end

    def summary_lines
      [
        "iNat source found:          #{@tally[:ok]}",
        "iNat source not found:      #{@tally[:not_found]}",
        "iNat fetch errors:          #{@tally[:fetch_error]}",
        "no import snapshot:         #{@tally[:no_snapshot]}",
        "--- migration delta ---",
        "has MO-side delta:          #{@tally[:has_delta]}",
        "  extra note keys:          #{@tally[:delta_note_keys]}",
        "  collector != uploader:    #{@tally[:collector_differs]}",
        "AMBIGUOUS (needs review):   #{@tally[:ambiguous]}",
        "  :Other residual:          #{@tally[:other_residual]}",
        "  image count mismatch:     #{@tally[:image_mismatch]}"
      ]
    end
  end
end
