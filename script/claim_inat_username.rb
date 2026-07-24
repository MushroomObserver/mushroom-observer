# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/claim_inat_username.rb -- \
#      --user <login|id> --inat <inat_username> [--dry-run]
#
#  DESCRIPTION::
#
#    Manual stand-in for an iNat user "claim" (no OAuth confirmation):
#    records that an MO user is a given iNat user and propagates that
#    identity the same way an import would, for observations that predate
#    the claim.
#
#    1. Sets users.inat_username -- only when currently nil; never clobbers
#       an existing value; aborts if another user already holds the login.
#    2. Re-links observations whose free-text `collector` is that iNat login
#       but whose collector_user_id is nil (e.g. obs another user imported
#       before this observer was known), via Observation.resolve_collector
#       -- the same resolver the importer uses.
#
#    Not recoverable by a claim, and therefore untouched: namings and
#    comments imported before the claim were attributed to the importer
#    (namer_for => importer when the suggester was unclaimed) and store no
#    iNat identifier, so there is nothing to match on. Those are correct
#    only if the identity existed at import time.
#
#    Idempotent and safe to re-run. --dry-run runs the whole thing in a
#    rolled-back transaction, so the reported counts are exact.

require "optparse"

class ClaimInatUsername
  def initialize(opts)
    @user_ref = opts[:user]
    @inat = opts[:inat]
    @dry_run = opts[:dry_run]
  end

  def run
    @user = find_user
    return warn("No MO user matching #{@user_ref.inspect}") unless @user

    puts("#{"[dry-run] " if @dry_run}claim #{@inat.inspect} for " \
         "##{@user.id} #{@user.login}")
    ActiveRecord::Base.transaction do
      relink_collectors if ensure_inat_username
      raise(ActiveRecord::Rollback) if @dry_run
    end
  end

  private

  def find_user
    if /\A\d+\z/.match?(@user_ref.to_s)
      User.find_by(id: @user_ref)
    else
      User.find_by(login: @user_ref)
    end
  end

  # Returns the user when the claim may proceed to the collector re-link,
  # or nil when it aborts.
  def ensure_inat_username
    current = @user.inat_username
    return proceed_with_existing(current) if current.present?

    holder = holder_of_inat_username
    if holder
      puts("  inat_username: #{@inat.inspect} already held by " \
           "##{holder.id} #{holder.login}; aborting")
      return nil
    end

    @user.update!(inat_username: @inat)
    puts("  inat_username: set -> #{@inat.inspect}")
    @user
  end

  # An already-set username is fine (idempotent) only when it's the same
  # login; a different one means this claim is wrong, so bail out.
  def proceed_with_existing(current)
    if current.casecmp?(@inat)
      puts("  inat_username: already #{current.inspect} (idempotent)")
      return @user
    end
    puts("  inat_username: user has DIFFERENT #{current.inspect}; aborting")
    nil
  end

  def holder_of_inat_username
    User.where.not(id: @user.id).
      find_by("LOWER(inat_username) = ?", @inat.downcase)
  end

  def relink_collectors
    candidates = Observation.where(collector_user_id: nil).
                 where("LOWER(collector) = ?", @inat.downcase).to_a
    linked = candidates.count { |obs| relink(obs) }
    verb = @dry_run ? "would re-link" : "re-linked"
    puts("  collector: #{verb} #{linked} of #{candidates.size} candidate obs")
  end

  # Re-links one observation when its collector resolves to the claimed
  # user; returns the obs id (truthy) when it did, else nil.
  def relink(obs)
    resolved = Observation.resolve_collector(
      obs.collector, owner: obs.user, existing: obs.collector_user,
                     match_inat: true
    )
    return unless resolved[:collector_user_id] == @user.id

    obs.update!(collector: resolved[:collector],
                collector_user_id: resolved[:collector_user_id])
    puts("    obs #{obs.id}: collector -> ##{@user.id} #{@user.login}")
    obs.id
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--user REF", "MO user login or id") { |v| options[:user] = v }
  opts.on("--inat NAME", "iNat username to claim") { |v| options[:inat] = v }
  opts.on("--dry-run", "Report without writing (rolled back)") do
    options[:dry_run] = true
  end
end.parse!

if options[:user].to_s.empty? || options[:inat].to_s.empty?
  abort("Usage: --user <login|id> --inat <username> [--dry-run]")
end

ClaimInatUsername.new(options).run
