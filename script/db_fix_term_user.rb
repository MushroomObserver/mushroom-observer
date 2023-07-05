#!/usr/bin/env ruby
# frozen_string_literal: true

# This script fixes certain incorrect glossary_term.user values in the db.
# In particular, it fixes values that were created by the bug that was fixed
# in PR 1530. https://github.com/MushroomObserver/mushroom-observer/pull/1530
#
# The script should be run once on any machine having those incorrect values.
# (It's useless, but not harmful, to run twice.)
# It should then be be deleted from that machine.
#
# USAGE
# rails runner script/db_fix_term_user.rb

GlossaryTerm.where.not(version: 1).each do |term|
  original = term.versions.first
  next if term.user_id == original.user_id

  term.update_column(:user_id, original.user_id)
end
