# frozen_string_literal: true

# MySQL serves a FLOAT to a client at single precision, so a value
# read back and compared against the row it came from misses: the
# client is handed 0.58 where the column holds 0.5799999833106995.
# The keyset pager hit this on a quality-ordered index (#5796), and
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
# `down` narrows, rounding any value written in the meantime to
# single precision. The stored data stays valid; two values that
# differed past the seventh digit may tie afterwards.
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

  def up
    convert(:double)
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
end
