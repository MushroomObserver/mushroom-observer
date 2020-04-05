# encoding: utf-8
class CleanRssLogs < ActiveRecord::Migration[4.2]
  def self.up
    cutoff = 1.year.ago

    i = 0
    num = RssLog.count
    old_pct = nil
    for log in RssLog.all
      i += 1
      pct = 100 * i / num
      if pct != old_pct
        $stdout.print "#{pct}%\r"
        $stdout.flush
      end
      old_pct = pct

      if log.modified && log.modified > cutoff
        new_notes, last_modified = clean_notes(log.notes, log.modified, cutoff)
      else
        new_notes = last_modified = nil
      end

      # Delete logs that haven't been used in a long time.
      if !last_modified || last_modified < cutoff
        if object = log.object
          object.rss_log = nil
          object.save_without_our_callbacks
        end
        log.destroy

      # Delete old entries from fresh logs.
      elsif new_notes != log.notes
        log.notes = new_notes
        log.save_without_our_callbacks
      end
    end
  end

  def self.down
  end

  def self.clean_notes(notes, modified, cutoff)
    result = []
    last_time = nil
    for line in notes.to_s
      # Fri Apr 03 00:47:19 -NNNN 2009
      # Fri Dec 01 09:13:07 PST 2006  -->  -0800
      # Fri Oct 06 20:01:01 PDT 2006  -->  -0700
      if match = line.match(/^\w+ (\w+) (\d+) (\d+):(\d+):(\d+) (\S+) (\d\d\d\d): *(.*)/)
        str = match[8]
        time = Time.utc(*match.values_at(7, 1, 2, 3, 4, 5))
        case zone = match[6]
        when /-(\d\d)00/
          time += Regexp.last_match(1).to_i.hours
        when "PDT"
          time += 7.hours
        when "PST"
          time += 8.hours
        end
        last_time ||= time

        # Reformat message only if we're going to keep it.
        if time < cutoff
          break
        else
          # Only keep the old "new" format.
          if str.match(/^([\w\%]+)\((.*)\)$/)
            tag = Regexp.last_match(1)
            args = {}
            for keyval in Regexp.last_match(2).split(",")
              if keyval.match(/=/)
                k = $`
                v = $'
                k = RssLog.unescape(k).to_sym
                v = RssLog.unescape(v)
                args[k] = v
              end
            end
            tag = RssLog.unescape(tag).to_sym
            result << RssLog.encode(tag, args, time)
          else
            puts str
          end
        end

      # Orphan title.
      elsif modified && modified > cutoff
        result << reescape(line)

      # Delete this entry.
      else
        last_time = nil
        break
      end
    end
    [result.join("\n"), last_time]
  end

  # The new format only escapes whitespace and percent signs.
  def self.reescape(str)
    RssLog.escape(RssLog.unescape(str))
  end
end

# These were the old old log messages -- these all go away now.
# elsif str.match(/^Approved by (.*?)\.?$/);                          key = :log_approved_by;            args = { :user => $1 }
# elsif str.match(/^Comment added by (.*?): (.*?)\.?$/);              key = :log_comment_added;          args = { :user => $1, :summary => $2 }
# elsif str.match(/^Comment destroyed by (.*?): (.*?)\.?$/);          key = :log_comment_destroyed;      args = { :user => $1, :summary => $2 }
# elsif str.match(/^Comment updated by (.*?): (.*?)\.?$/);            key = :log_comment_updated;        args = { :user => $1, :summary => $2 }
# elsif str.match(/^Consensus established: (.*?)\.?$/);               key = :log_consensus_reached;      args = { :name => $1 }
# elsif str.match(/^Consensus rejected (.*?) in favor of (.*?)\.?$/); key = :log_consensus_changed;      args = { :old => $1, :new => $2 }
# elsif str.match(/^Deprecated by (.*?)\.?$/);                        key = :log_deprecated_by;          args = { :user => $1 }
# elsif str.match(/^Deprecated in favor of (.*?) by (.*?)\.?$/);      key = :log_name_deprecated;        args = { :user => $2, :other => $1 }
# elsif str.match(/^Image created by (.*?): (.*?)\.?$/);              key = :log_image_created;          args = { :user => $1, :name => $2 }
# elsif str.match(/^Image destroyed by (.*?): (.*?)\.?$/);            key = :log_image_destroyed;        args = { :user => $1, :name => $2 }
# elsif str.match(/^Image removed by (.*?): (.*?)\.?$/);              key = :log_image_removed;          args = { :user => $1, :name => $2 }
# elsif str.match(/^Image removed (.*?)\.?$/);                        key = :log_image_removed;          args = { :user => '', :name => $1 }
# elsif str.match(/^Image reused by (.*?): (.*?)\.?$/);               key = :log_image_reused;           args = { :user => $1, :name => $2 }
# elsif str.match(/^Name deprecated by (.*?)\.?$/);                   key = :log_deprecated_by;          args = { :user => $1 }
# elsif str.match(/^Name merged with (.*?)\.?$/);                     key = :log_name_merged;            args = { :name => $1 }
# elsif str.match(/^Name updated by (.*?)\.?$/);                      key = :log_name_updated;           args = { :user => $1 }
# elsif str.match(/^Naming changed by (.*?): (.*?)\.?$/);             key = :log_naming_updated;         args = { :user => $1, :name => $2 }
# elsif str.match(/^Naming created by (.*?): (.*?)\.?$/);             key = :log_naming_created;         args = { :user => $1, :name => $2 }
# elsif str.match(/^Naming deleted by (.*?): (.*?)\.?$/);             key = :log_naming_destroyed;       args = { :user => $1, :name => $2 }
# elsif str.match(/^Observation created by (.*?)\.?$/);               key = :log_observation_created;    args = { :user => $1 }
# elsif str.match(/^Observation destroyed by (.*?)\.?$/);             key = :log_observation_destroyed;  args = { :user => $1 }
# elsif str.match(/^Observation updated by (.*?)\.?$/);               key = :log_observation_updated;    args = { :user => $1 }
# elsif str.match(/^Preferred over (.*?) by (.*?)\.?$/);              key = :log_name_approved;          args = { :user => $2, :other => $1 }
# elsif str.match(/^Species list created by (.*?)\.?$/);              key = :log_species_list_created;   args = { :user => $1 }
# elsif str.match(/^Species list destroyed by (.*?)\.?$/);            key = :log_species_list_destroyed; args = { :user => $1 }
# elsif str.match(/^Species list updated by (.*?)\.?$/);              key = :log_species_list_updated;   args = { :user => $1 }
# elsif str.match(/^Updated by (.*?)\.?$/);                           key = :log_updated_by;             args = { :user => $1 }
# elsif str.match(/^Comment, (.*?), added by (.*?)\.?$/);             key = :log_comment_added;          args = { :user => $2, :summary => $1 }
# elsif str.match(/^Comment, (.*?), updated by (.*?)\.?$/);           key = :log_comment_updated;        args = { :user => $2, :summary => $1 }
# elsif str.match(/^Comment, (.*?), destroyed by (.*?)\.?$/);         key = :log_comment_destroyed;      args = { :user => $2, :summary => $1 }
# elsif str.match(/^Image, (.*?), created by (.*?)\.?$/);             key = :log_image_created;          args = { :user => $2, :name => $1 }
# elsif str.match(/^Image, (.*?), destroyed by (.*?)\.?$/);           key = :log_image_destroyed;        args = { :user => $2, :name => $1 }
# elsif str.match(/^Image, (.*?), removed by (.*?)\.?$/);             key = :log_image_removed;          args = { :user => $2, :name => $1 }
# elsif str.match(/^Image, (.*?), updated by (.*?)\.?$/);             key = :log_image_updated;          args = { :user => $2, :name => $1 }
# elsif str.match(/^Image, (.*?), reused by (.*?)\.?$/);              key = :log_image_reused;           args = { :user => $2, :name => $1 }
# elsif str.match(/^Observation, (.*?), destroyed by (.*?)\.?$/);     key = :log_observation_destroyed2; args = { :user => $2, :name => $1 }
# elsif str.match(/^(.*?) merged with (.*?)\.?$/);                    key = :log_name_merged;            args = { :name => $2 }
# else
#   key = :log_ancient
#   args = { :string => str }
# end
