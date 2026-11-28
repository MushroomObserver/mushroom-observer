# frozen_string_literal: true

require("test_helper")

# Enforces the "double precision, not single" rule from
# `.claude/rules/no_single_precision_floats.md`.
#
# MySQL serves a FLOAT to a client at single precision, so a value
# read back does not compare equal to the row it came from: the
# client is handed 0.58 where the column holds 0.5799999833106995.
# Any comparison seeded from a stored value then misses -- the
# keyset pager matched the current row against itself (#5796), and
# a single-value confidence filter matches nothing.
#
# `t.float` on MySQL means single precision, so the declaration a
# new column needs is `t.column(:name, :double)`. The schema dumper
# writes that back as `t.float "name", limit: 53`, which is why this
# test reads the loaded schema rather than the file.
class NoSinglePrecisionFloatColumnsTest < ActiveSupport::TestCase
  def test_no_single_precision_float_columns
    offenders = single_precision_columns

    assert_empty(offenders, failure_message(offenders))
  end

  def test_the_scanner_recognizes_both_precisions
    connection.create_table(:zz_precision_probe, force: true) do |t|
      t.float(:single)
      t.column(:dbl, :double)
    end
    columns = connection.columns(:zz_precision_probe)

    assert(single_precision?(columns.find { |c| c.name == "single" }))
    assert_not(single_precision?(columns.find { |c| c.name == "dbl" }))
  ensure
    connection.drop_table(:zz_precision_probe, if_exists: true)
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  # The primary schema. Solid Cache and Solid Queue hold no floating
  # point columns, and their tables are not MO's to declare.
  def single_precision_columns
    connection.tables.sort.flat_map do |table|
      connection.columns(table).select { |column| single_precision?(column) }.
        map { |column| "#{table}.#{column.name} (#{column.sql_type})" }
    end
  end

  def single_precision?(column)
    column.type == :float && column.limit.to_i < 53
  end

  def failure_message(offenders)
    return "" if offenders.empty?

    <<~MSG
      Single-precision floating point columns found.

      MySQL hands a FLOAT to the client at single precision, so a
      value read back compares unequal to the row it came from, and
      any query seeded from a stored value silently misses.

      Declare the column as `t.column(:name, :double)` and convert
      these with a migration following
      db/migrate/20261128120000_convert_float_columns_to_double.rb.

      Offenders:
      #{offenders.map { |o| "  #{o}" }.join("\n")}
    MSG
  end
end
