# frozen_string_literal: true

# MySQL serves a FLOAT to a client at single precision, so a value
# read back misses when it is compared against the row it came from:
# the client is handed 0.58 where the column holds 0.5799999833106995.
# The keyset pager matched the current row against itself (#5796), and
# Naming's confidence filter has the same shape -- a single-value
# filter is `where(vote_cache: min..min)`, which matches nothing for
# a value single precision cannot hold. A DOUBLE survives the round
# trip to the client and back into a literal, which settles the
# class rather than one case of it.
#
# Widening is a column type change, so MySQL refuses INPLACE and
# rebuilds table and indexes: about 1GB across the eight tables.
# Each table takes one combined ALTER, per the measurements in
# .claude/rules/migration_cost.md.
#
# Widening is exact, so a row keeps the value single precision had
# rounded it to, and a fresh computation gives a different double --
# 5,190 of the 143,586 images carrying a vote, and about three fifths
# of the namings and observations. Recomputing the image averages is
# one group-by and some 200 updates, so it happens here. The naming
# and observation caches need the consensus calculator at about 5ms
# an observation, an hour over the table, so those two are
# `script/refresh_vote_caches.rb`, run with the site up.
#
# `down` needs no pass of either kind: narrowing rounds every value
# to single precision, which is the value the column held before
# this migration ran.
class ConvertFloatColumnsToDouble < ActiveRecord::Migration[7.2]
  COLUMNS = {
    images: [:vote_cache],
    inat_imports: [:avg_import_time],
    inat_obs_extracts: [:public_accuracy],
    location_versions: [:north, :south, :west, :east, :high, :low],
    locations: [:high, :low],
    namings: [:vote_cache],
    observations: [:vote_cache],
    votes: [:value, :source_value]
  }.freeze

  # Copies of the two tables this migration reads, rather than the
  # application's models -- those go on changing after a migration is
  # written.
  class MigrationImage < ActiveRecord::Base
    self.table_name = "images"
  end

  class MigrationImageVote < ActiveRecord::Base
    self.table_name = "image_votes"
  end

  def up
    convert(:double)
    restore_image_vote_caches
  end

  def down
    convert(:float)
  end

  private

  # `change_column` carries the existing default, nullability and
  # comment over, so only the type is named here.
  def convert(type)
    COLUMNS.each do |table, columns|
      change_table(table, bulk: true) do |t|
        columns.each { |column| t.change(column, type) }
      end
    end
  end

  def restore_image_vote_caches
    fresh = fresh_averages
    changed = fresh.reject { |id, value| stored_averages[id] == value }
    say("#{changed.size} of #{fresh.size} image vote caches recomputed")
    write_image_averages(changed)
  end

  def stored_averages
    @stored_averages ||= MigrationImage.where.not(vote_cache: nil).
                         pluck(:id, :vote_cache).to_h
  end

  # `update_all` leaves updated_at alone, which an image needs: the
  # cache-busting URL token is derived from it.
  def write_image_averages(changed)
    changed.group_by { |_id, value| value }.each do |value, pairs|
      MigrationImage.where(id: pairs.map(&:first)).
        update_all(vote_cache: value)
    end
  end

  # Image#refresh_vote_cache! averages the votes in Ruby, so the sum
  # and the count come back separately: MySQL's AVG over an integer
  # column answers as a DECIMAL four places past the input scale, and
  # disagrees with the Ruby division for 4,288 of these images.
  def fresh_averages
    votes = MigrationImageVote.where.not(image_id: nil)
    sums = votes.group(:image_id).sum(:value)
    counts = votes.group(:image_id).count
    sums.to_h { |id, sum| [id, sum.to_f / counts[id]] }
  end
end
