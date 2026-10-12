# frozen_string_literal: true

# Hand back the confidence votes an observer set on an imported
# observation, so the nightly resync stops overwriting them (#5480).
#
#   bin/rails runner script/unstamp_observer_votes.rb
#   bin/rails runner script/unstamp_observer_votes.rb --apply
#
#     --apply         write; without it nothing changes
#     --min-value N   only votes at or above N (default 2, "Promising")
#     --user LOGIN    only this observer's votes
#     --all-values    every edited vote, including those at Could Be
#
# `Inat::ReflectionResync::TaxonSync` writes its vote as the
# observation's owner, who is the observer when someone imports their
# iNaturalist observations. Until #5480 the stamp that marks a vote as
# the source's survived a person changing it, so the resync kept moving
# a value its holder had considered and set. The code now gives up the
# stamp on any change, which protects a vote edited from here on; a vote
# edited before that cannot be told apart from one the resync wrote,
# because both leave `updated_at` later than `created_at` and both land
# on one of the three positive values.
#
# So the selection is a judgement, not a proof: a stamped vote the
# observer holds, edited since it was written, at or above Promising.
# A resync writes Promising for research grade and I'd Call It That for
# sequence evidence, so some of these are the resync's, and unstamping
# them means the resync stops managing them -- the value stays where it
# is rather than following iNaturalist. That is the mild direction. The
# other direction is the bug.
#
# Read the dry run. `--all-values` widens to votes at Could Be, which
# are mostly the resync's writes and worth leaving alone.

MIN_VALUE_DEFAULT = Vote::NEXT_BEST_VOTE

# "2.0" says little by itself; the menu carries the wording a voter saw.
# Vote values are a fixed set of halves and wholes, so a small epsilon
# is enough to match one.
def confidence_label(value)
  tag, = Vote::CONFIDENCE_VALS.find { |_t, val| (val - value.to_f).abs < 0.01 }
  tag ? tag.l : value.to_s
end

def die(message)
  warn("error: #{message}")
  warn("usage: bin/rails runner script/unstamp_observer_votes.rb " \
       "[--apply] [--min-value N] [--user LOGIN] [--all-values]")
  exit(1)
end

def parse_one(arg, argv, opts)
  case arg
  when "--apply" then opts[:apply] = true
  when "--min-value" then opts[:min_value] = argv.shift.to_f
  when "--user" then opts[:user] = argv.shift
  when "--all-values" then opts[:min_value] = Vote::MIN_POS_VOTE
  else die("unexpected argument #{arg.inspect}")
  end
end

def parse_argv(argv)
  opts = { apply: false, min_value: MIN_VALUE_DEFAULT }
  parse_one(argv.shift, argv, opts) until argv.empty?
  opts
end

OPTS = parse_argv(ARGV.dup)
SITE = ExternalSite.inaturalist
die("no iNaturalist external site") unless SITE

observer = nil
if OPTS[:user]
  observer = User.find_by(login: OPTS[:user])
  die("no such user: #{OPTS[:user]}") unless observer
end

# A vote the resync manages, held by the observation's owner, whose
# value has moved since the row was written.
def candidates(site, min_value, observer)
  scope = Vote.joins(:observation).
          where(external_site_id: site.id).
          where(Vote[:user_id].eq(Observation[:user_id])).
          where(Vote[:updated_at].gt(Vote[:created_at])).
          where(Vote[:value].gteq(min_value))
  observer ? scope.where(user_id: observer.id) : scope
end

rows = candidates(SITE, OPTS[:min_value], observer).
       includes(:observation, :user, naming: :name).to_a

puts("votes to hand back: #{rows.size}")
puts("  at or above #{OPTS[:min_value]} " \
     "(#{confidence_label(OPTS[:min_value])})")
puts("  observer: #{observer.login}") if observer
puts

rows.group_by(&:value).sort.reverse_each do |value, votes|
  puts("#{votes.size} at #{value} (#{confidence_label(value)})")
end

puts
by_user = rows.group_by(&:user)
puts("across #{by_user.size} #{"observer".pluralize(by_user.size)}:")
by_user.sort_by { |_user, votes| -votes.size }.first(10).each do |user, votes|
  puts format("   %-20s %d", user.login, votes.size)
end

puts("\nfirst few:")
rows.first(10).each do |vote|
  puts format("   MO%-8d %-34s %.1f  %s", vote.observation_id,
              vote.naming&.name&.text_name, vote.value, vote.user.login)
end

unless OPTS[:apply]
  puts("\nDry run - nothing written. To apply: " \
       "bin/rails runner script/unstamp_observer_votes.rb --apply")
  return
end

# update_column: the value is not changing, only who holds it, and a
# callback here would recompute a consensus that is already correct.
written = 0
rows.each do |vote|
  vote.update_column(:external_site_id, nil)
  written += 1
  warn("  #{written}/#{rows.size}") if (written % 200).zero?
end
puts("\nhanded back #{written} #{"vote".pluralize(written)}")
puts("the resync no longer moves these; a later edit keeps working " \
     "the same way")
