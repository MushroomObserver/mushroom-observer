# frozen_string_literal: true

# Restore the deleted RssLogs of observations that lost their history when a
# pre-#4764 touch turned their orphaned log into a "ghost" that
# script/check_rss_logs then deleted (GitHub issue #4763).
#
# All notes below are the REAL original logs, recovered from database backups
# (2024-01-01 for the first three; 2019-01-27 for the rest, which predates
# every detonation) and cleaned the same way a zombie is cleaned: the false
# title line and the log_observation_destroyed entry are dropped, leaving the
# genuine pre-2016 history. Each log is reinserted with its original id,
# observation_id, and an updated_at matching its newest surviving entry.
#
# obs 140593 is special: it already has a fresh log (682221) from post-2024
# activity, whose entries are authentic and kept verbatim. Its recovered
# pre-detonation history is appended BELOW them, so nothing is duplicated.
#
# Usage (dry run by default; --apply to write):
#   bin/rails runner script/restore_deleted_observation_logs.rb
#   bin/rails runner script/restore_deleted_observation_logs.rb --apply

# Recreates deleted observation logs from backup-recovered notes.
class DeletedObservationLogRestorer
  INSERTS = [
    # obs 159258 -- Phellinus gilvus
    {
      log_id: 182_192, obs_id: 159_258,
      created_at: "2014-02-06 21:50:32", updated_at: "2014-02-06 21:50:41",
      notes: <<~NOTES.chomp
        20140206215041 log_observation_created_at user bloodworm
        20140206215041 log_image_created_at name Image%20#402504 user bloodworm
        20140206215040 log_consensus_changed new **__Phellinus%20gilvus__**%20(Schwein.)%20Pat. old **__Fungi__** user bloodworm
      NOTES
    },
    # obs 218032 -- Chromosera cyanophylla
    {
      log_id: 247_617, obs_id: 218_032,
      created_at: "2015-10-07 21:59:02", updated_at: "2015-10-07 21:59:11",
      notes: <<~NOTES.chomp
        20151007215911 log_observation_created_at user inspiteofourselves
        20151007215911 log_image_created_at name Image%20#562015 user inspiteofourselves
        20151007215909 log_image_created_at name Image%20#562014 user inspiteofourselves
        20151007215908 log_consensus_changed new **__Chromosera%20cyanophylla__**%20(Fr.)%20Redhead,%20Ammirati%20&%20Norvell old **__Fungi__**%20Bartl. user inspiteofourselves
      NOTES
    },
    # obs 223025 -- Hericium erinaceus
    {
      log_id: 253_226, obs_id: 223_025,
      created_at: "2015-11-15 07:16:18", updated_at: "2015-11-15 07:16:23",
      notes: <<~NOTES.chomp
        20151115071623 log_observation_created_at user inspiteofourselves
        20151115071623 log_image_created_at name Image%20#575862 user inspiteofourselves
        20151115071621 log_consensus_changed new **__Hericium%20erinaceus__**%20(Bull.)%20Pers. old **__Fungi__**%20Bartl. user inspiteofourselves
      NOTES
    },
    # obs 96712 -- Callistosporium
    {
      log_id: 105_921, obs_id: 96_712,
      created_at: "2012-06-08 22:37:23", updated_at: "2014-10-29 09:05:32",
      notes: <<~NOTES.chomp
        20141029090532 log_comment_added summary thanks%20Jacob user myxomop
        20141029002739 log_comment_updated summary myxomop user Pulk
        20141029002726 log_comment_added summary myxomop user Pulk
        20120911105259 log_comment_updated summary forgive%20me user myxomop
        20120911034756 log_comment_added summary forgive%20me user myxomop
        20120911031200 log_comment_updated summary Danny... user bloodworm
        20120911031114 log_comment_added summary Danny... user bloodworm
        20120910220942 log_comment_added summary too%20immature user myxomop
        20120910220923 log_consensus_changed new **__Agaricales__**%20sensu%20lato old **__Callistosporium__**%20Singer user myxomop
        20120909134524 log_consensus_changed new **__Callistosporium__**%20Singer old **__Agaricales__**%20sensu%20lato user bloodworm
        20120831190454 log_consensus_changed new **__Agaricales__**%20sensu%20lato old **__Callistosporium__**%20Singer user myxomop
        20120831130517 log_naming_created name **__Callistosporium__**%20Singer user bloodworm
        20120831130517 log_consensus_changed new **__Callistosporium__**%20Singer old **__Agaricales__**%20sensu%20lato user bloodworm
        20120831083038 log_naming_created name **__Agaricales__**%20sensu%20lato user myxomop
        20120831083038 log_consensus_changed new **__Agaricales__**%20sensu%20lato old **__Fungi__**%20Bartling user myxomop
        20120831082121 log_naming_created name **__Collybia%20aurea__**%20(Beeli)%20Pegler user myxomop
        20120608223725 log_observation_created user bloodworm
        20120608223725 log_image_created name Image%20#225942 user bloodworm
        20120608223725 log_image_created name Image%20#225941 user bloodworm
      NOTES
    },
    # obs 131983 -- Panaeolus cinctulus
    {
      log_id: 149_611, obs_id: 131_983,
      created_at: "2013-04-16 15:24:10", updated_at: "2014-02-06 17:02:39",
      notes: <<~NOTES.chomp
        20140206170239 log_comment_added summary Light%20stem user Byrain
        20140206165208 log_naming_created_at name **__Panaeolus__**%20(Fr.)%20Quél. user Byrain
        20140206165208 log_consensus_changed new **__Panaeolus__**%20(Fr.)%20Quél. old **__Panaeolus%20subbalteatus__**%20(Berk.%20&%20Broome)%20Sacc. user Byrain
        20140206164139 log_comment_updated summary thanks%20Alan... user bloodworm
        20140206164034 log_comment_added summary thanks%20Alan... user bloodworm
        20131214214422 log_naming_created_at name **__Panaeolus%20subbalteatus__**%20(Berk.%20&%20Broome)%20Sacc. user Alan%20Rockefeller
        20131214214422 log_consensus_changed new **__Panaeolus%20subbalteatus__**%20(Berk.%20&%20Broome)%20Sacc. old __Panaeolus%20cinctulus__%20(Bolton)%20Britzelm. user Alan%20Rockefeller
        20130416152414 log_observation_created user bloodworm
        20130416152414 log_image_created name Image%20#322869 user bloodworm
        20130416152414 log_image_created name Image%20#322868 user bloodworm
        20130416152413 log_consensus_changed new **__Panaeolus%20cinctulus__**%20(Bolton)%20Britzelm. old **__Fungi__**%20Bartl. user bloodworm
      NOTES
    },
    # obs 205554 -- Psathyrella carbonicola
    {
      log_id: 233_520, obs_id: 205_554,
      created_at: "2015-06-03 05:13:35", updated_at: "2015-06-03 05:40:35",
      notes: <<~NOTES.chomp
        20150603054035 log_naming_created_at name **__Psathyrella%20carbonicola__**%20A.H.%20Sm. user Pulk
        20150603054035 log_consensus_changed new **__Psathyrella%20carbonicola__**%20A.H.%20Sm. old **__Psathyrella__**%20(Fr.)%20Quél. user Pulk
        20150603051337 log_observation_created_at user RJK
        20150603051337 log_image_created_at name Image%20#524468 user RJK
        20150603051336 log_image_created_at name Image%20#524467 user RJK
        20150603051336 log_consensus_changed new **__Psathyrella__**%20(Fr.)%20Quél. old **__Fungi__**%20Bartl. user RJK
      NOTES
    }
  ].freeze

  APPENDS = [
    # obs 140593 -- recovered pre-detonation history spliced below the
    # authentic 2024-2025 entries of its existing fresh log 682221.
    {
      existing_log_id: 682_221, obs_id: 140_593,
      notes: <<~NOTES.chomp
        20140704155136 log_consensus_changed new **__Copelandia__**%20Bres. old **__Copelandia%20cambodginiensis__**%20(Ola'h%20&%20R.%20Heim)%20Singer%20&%20R.A.%20Weeks user bloodworm
        20140704155058 log_consensus_changed new **__Copelandia%20cambodginiensis__**%20(Ola'h%20&%20R.%20Heim)%20Singer%20&%20R.A.%20Weeks old **__Copelandia__**%20Bres. user bloodworm
        20140629061933 log_consensus_changed new **__Copelandia__**%20Bres. old **__Panaeolus%20cyanescens__**%20(Berk.%20&%20Broome)%20Sacc. user bloodworm
        20140629061734 log_consensus_changed new **__Panaeolus%20cyanescens__**%20(Berk.%20&%20Broome)%20Sacc. old **__Copelandia__**%20Bres. user Alan%20Rockefeller
        20140223170314 log_comment_updated summary Time%20to%20figure%20out%20 user Byrain
        20140223170114 log_consensus_changed new **__Copelandia__**%20Bres. old **__Copelandia%20cambodginiensis__** user Byrain
        20140223164659 log_comment_updated summary Time%20to%20figure%20out%20 user Byrain
        20140223164610 log_comment_added summary Time%20to%20figure%20out%20 user Byrain
        20140223133236 log_comment_added summary Time%20to%20figure%20out user Rocky%20Houghtby
        20140223085609 log_naming_created_at name **__Copelandia%20cambodginiensis__** user bloodworm
        20140223085609 log_consensus_changed new **__Copelandia%20cambodginiensis__** old **__Copelandia__**%20Bres. user bloodworm
        20140202165257 log_consensus_changed new **__Copelandia__**%20Bres. old **__Panaeolus%20cambodginiensis__**%20Ola'h%20and%20Heim user Byrain
        20140202161222 log_naming_created_at name **__Panaeolus%20cambodginiensis__**%20Ola'h%20and%20Heim user bloodworm
        20140202161222 log_consensus_changed new **__Panaeolus%20cambodginiensis__**%20Ola'h%20and%20Heim old **__Copelandia__**%20Bres. user bloodworm
        20140104125741 log_consensus_changed new **__Copelandia__**%20Bres. old **__Panaeolus__**%20subgenus%20**__Copelandia__** user bloodworm
        20131230190338 log_comment_added summary Well user Byrain
        20131230081128 log_naming_created_at name __Copelandia__%20Bres. user Alan%20Rockefeller
        20131230061628 log_consensus_changed new **__Panaeolus__**%20subgenus%20**__Copelandia__** old **__Panaeolus%20bisporus__**%20(Malençon%20&%20Bertault)%20Ew.%20Gerhardt user Joust
        20131230050307 log_consensus_changed new **__Panaeolus%20bisporus__**%20(Malençon%20&%20Bertault)%20Ew.%20Gerhardt old **__Panaeolus%20cyanescens__**%20(Berk.%20&%20Broome)%20Sacc. user bloodworm
        20131230045705 log_comment_added summary thanks%20Christine!! user bloodworm
        20130808181111 log_observation_updated user wintersbefore
        20130802172049 log_comment_added summary Spore%20measurements user wintersbefore
        20130802170504 log_comment_added summary bloodworm user Byrain
        20130802170417 log_consensus_changed new **__Panaeolus%20cyanescens__**%20(Berk.%20&%20Broome)%20Sacc. old **__Panaeolus__**%20(Fr.)%20Quél. user Byrain
        20130802151243 log_image_created name Image%20#354418 user wintersbefore
        20130802151146 log_image_created name Image%20#354417 user wintersbefore
        20130802151145 log_image_created name Image%20#354416 user wintersbefore
        20130802145910 log_image_created name Image%20#354415 user wintersbefore
        20130802145909 log_image_created name Image%20#354414 user wintersbefore
        20130802145908 log_image_created name Image%20#354413 user wintersbefore
        20130802145907 log_image_created name Image%20#354412 user wintersbefore
        20130802145634 log_image_created name Image%20#354407 user wintersbefore
        20130802145634 log_image_created name Image%20#354406 user wintersbefore
        20130802145633 log_image_created name Image%20#354405 user wintersbefore
        20130802145426 log_image_created name Image%20#354401 user wintersbefore
        20130802145426 log_image_created name Image%20#354400 user wintersbefore
        20130802145425 log_image_created name Image%20#354399 user wintersbefore
        20130802145424 log_image_created name Image%20#354398 user wintersbefore
        20130802145047 log_image_created name Image%20#354397 user wintersbefore
        20130802144747 log_image_created name Image%20#354396 user wintersbefore
        20130802144013 log_image_created name Image%20#354395 user wintersbefore
        20130802144011 log_image_created name Image%20#354394 user wintersbefore
        20130802144009 log_image_created name Image%20#354393 user wintersbefore
        20130802144008 log_image_created name Image%20#354392 user wintersbefore
        20130802143840 log_image_created name Image%20#354391 user wintersbefore
        20130802143839 log_image_created name Image%20#354390 user wintersbefore
        20130802143737 log_image_created name Image%20#354389 user wintersbefore
        20130802143736 log_image_created name Image%20#354388 user wintersbefore
        20130802143735 log_image_created name Image%20#354387 user wintersbefore
        20130802143734 log_image_created name Image%20#354386 user wintersbefore
        20130723065327 log_comment_added summary Byrain... user bloodworm
        20130723064737 log_comment_added summary Micro? user Byrain
        20130723064552 log_consensus_changed new **__Panaeolus__**%20(Fr.)%20Quél. old **__Panaeolus%20bisporus__**%20(Malençon%20&%20Bertault)%20Ew.%20Gerhardt user Byrain
        20130723050524 log_consensus_changed new **__Panaeolus%20bisporus__**%20(Malençon%20&%20Bertault)%20Ew.%20Gerhardt old **__Panaeolus__**%20(Fr.)%20Quél. user bloodworm
        20130722144024 log_naming_created name **__Panaeolus%20bisporus__**%20(Malençon%20&%20Bertault)%20Ew.%20Gerhardt user bloodworm
        20130722130617 log_image_created name Image%20#351215 user bloodworm
        20130722130501 log_image_removed name Image%20#351214 user bloodworm
        20130722130113 log_image_created name Image%20#351214 user bloodworm
        20130722124428 log_naming_created name **__Panaeolus%20cyanescens__**%20(Berk.%20&%20Broome)%20Sacc. user bloodworm
        20130722123932 log_naming_created name **__Panaeolus__**%20subgenus%20**__Copelandia__** user bloodworm
        20130722122825 log_observation_created user bloodworm
        20130722122825 log_specimen_added name Panaeolus%20:%20140593 user bloodworm
        20130722122825 log_image_created name Image%20#351211 user bloodworm
        20130722122824 log_image_created name Image%20#351210 user bloodworm
        20130722122824 log_image_created name Image%20#351209 user bloodworm
        20130722122824 log_image_created name Image%20#351208 user bloodworm
        20130722122824 log_image_created name Image%20#351207 user bloodworm
        20130722122824 log_consensus_changed new **__Panaeolus__**%20(Fr.)%20Quél. old **__Fungi__**%20Bartl. user bloodworm
      NOTES
    }
  ].freeze

  def initialize(apply:)
    @dry_run = !apply
    @done = 0
    @skipped = []
  end

  def run
    warn("#{"[DRY RUN] " if @dry_run}Restoring #{INSERTS.size} log(s) + " \
         "#{APPENDS.size} splice(s).\n\n")
    INSERTS.each { |rec| insert_record(rec) }
    APPENDS.each { |rec| append_record(rec) }
    report
  end

  private

  def insert_record(rec)
    return skip(rec, "log exists") if RssLog.exists?(rec[:log_id])

    obs = Observation.find_by(id: rec[:obs_id])
    return skip(rec, "obs not found") unless obs
    return skip(rec, "obs already points at another log") unless linkable?(obs,
                                                                           rec)

    write_insert(rec, obs) unless @dry_run
    done("insert log #{rec[:log_id]} -> obs #{rec[:obs_id]}")
  end

  # Only overwrite rss_log_id when it's blank or already this log, so a log
  # created since this script was authored (as 140593 got) is never clobbered.
  def linkable?(obs, rec)
    obs.rss_log_id.nil? || obs.rss_log_id == rec[:log_id]
  end

  def write_insert(rec, obs)
    RssLog.insert!({ id: rec[:log_id], observation_id: rec[:obs_id],
                     notes: rec[:notes], created_at: utc(rec[:created_at]),
                     updated_at: utc(rec[:updated_at]) })
    obs.update_column(:rss_log_id, rec[:log_id])
  end

  # Recovered timestamps are UTC wall-clock; parse them as UTC so they aren't
  # shifted through the app time zone.
  def utc(str)
    Time.find_zone("UTC").parse(str)
  end

  def append_record(rec)
    log = RssLog.find_by(id: rec[:existing_log_id])
    return skip(rec, "log missing") unless log
    return skip(rec, "obs missing or points elsewhere") unless spliceable?(rec)
    return skip(rec, "already spliced") if log.notes.to_s.include?(rec[:notes])

    log.update_columns(notes: spliced(log, rec)) unless @dry_run
    done("splice history -> obs #{rec[:obs_id]} (log #{rec[:existing_log_id]})")
  end

  def spliceable?(rec)
    Observation.find_by(id: rec[:obs_id])&.rss_log_id == rec[:existing_log_id]
  end

  def spliced(log, rec)
    "#{log.notes.to_s.chomp}\n#{rec[:notes]}"
  end

  def done(msg)
    @done += 1
    warn("#{@dry_run ? "WOULD" : "DID"} #{msg}")
  end

  def skip(rec, reason)
    log_id = rec[:log_id] || rec[:existing_log_id]
    @skipped << [rec[:obs_id], log_id, reason]
    warn("SKIP obs #{rec[:obs_id]} log #{log_id}: #{reason}")
  end

  def report
    warn("\n#{@dry_run ? "[DRY RUN] would apply" : "Applied"} #{@done}, " \
         "skipped #{@skipped.size}.")
    return unless @dry_run && @done.positive?

    warn("Re-run with --apply to write the changes.")
  end
end

DeletedObservationLogRestorer.new(apply: ARGV.include?("--apply")).run
