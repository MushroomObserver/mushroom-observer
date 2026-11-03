# frozen_string_literal: true

# Reads a deploy time typed by a person, for script/prerelease.rb.
#
#   time    8pm, 8am, 8 pm    explicit
#           08:00, 20:00      24-hour (leading zero, or an hour of 13+)
#           8, 8:00, 12:30    the next time the clock reads that, am or
#                             pm; with a day, the first one that day
#           noon, midnight
#   day     today, tomorrow, day after tomorrow, a weekday (the next
#           one), YYYY-MM-DD; optional, before or after the time
#   zone    optional, anywhere; the machine's zone when left out
#           UTC, GMT, Z
#           eastern, central, mountain, pacific (and ET, CT, MT, PT)
#           a tz database abbreviation (EST, EDT, BST, CET, ...), valid
#           only on dates the zone uses it: EST in July is rejected
#           an IANA name (America/New_York) or offset (+02:00)
require("date")
require("tzinfo")

# Parses a person's deploy time into a UTC Time.
class DeployTime
  class Error < StandardError; end

  Result = Data.define(:time, :zone)

  ALWAYS = {
    "utc" => "Etc/UTC", "gmt" => "Etc/UTC", "z" => "Etc/UTC",
    "eastern" => "America/New_York", "et" => "America/New_York",
    "central" => "America/Chicago", "ct" => "America/Chicago",
    "mountain" => "America/Denver", "mt" => "America/Denver",
    "pacific" => "America/Los_Angeles", "pt" => "America/Los_Angeles"
  }.freeze

  # Each abbreviation is accepted only when one of its zones uses it at
  # the parsed time. Ambiguous ones (IST: India, Ireland or Israel) are
  # left out; CST means US Central.
  ABBREVIATIONS = {
    "est" => ["America/New_York"], "edt" => ["America/New_York"],
    "cst" => ["America/Chicago"], "cdt" => ["America/Chicago"],
    "mst" => ["America/Denver", "America/Phoenix"],
    "mdt" => ["America/Denver"],
    "pst" => ["America/Los_Angeles"], "pdt" => ["America/Los_Angeles"],
    "akst" => ["America/Anchorage"], "akdt" => ["America/Anchorage"],
    "hst" => ["Pacific/Honolulu"],
    "ast" => ["America/Halifax"], "adt" => ["America/Halifax"],
    "nst" => ["America/St_Johns"], "ndt" => ["America/St_Johns"],
    "bst" => ["Europe/London"],
    "wet" => ["Europe/Lisbon"], "west" => ["Europe/Lisbon"],
    "cet" => ["Europe/Paris"], "cest" => ["Europe/Paris"],
    "eet" => ["Europe/Athens"], "eest" => ["Europe/Athens"],
    "msk" => ["Europe/Moscow"], "sast" => ["Africa/Johannesburg"],
    "hkt" => ["Asia/Hong_Kong"], "jst" => ["Asia/Tokyo"],
    "kst" => ["Asia/Seoul"], "awst" => ["Australia/Perth"],
    "acst" => ["Australia/Adelaide"], "acdt" => ["Australia/Adelaide"],
    "aest" => ["Australia/Sydney", "Australia/Brisbane"],
    "aedt" => ["Australia/Sydney"],
    "nzst" => ["Pacific/Auckland"], "nzdt" => ["Pacific/Auckland"]
  }.freeze

  WEEKDAYS = %w[sunday monday tuesday wednesday thursday friday
                saturday].freeze
  CLOCK = /\A(?<hour>\d{1,2})(?::(?<min>\d{2}))?(?<half>am|pm)?\z/
  OFFSET = /\A(?<sign>[+-])(?<hours>\d{1,2}):?(?<mins>\d{2})?\z/
  EXAMPLES = "e.g. 8pm, '08:00 tomorrow', 'monday 9am UTC'"

  # A UTC offset given as "+02:00", which no tz database zone stands for.
  FixedZone = Data.define(:offset, :name) do
    def local_to_utc(wall) = Time.at(wall.to_i - offset).utc
    def to_local(time) = time.getlocal(offset)
  end

  def self.parse(text, now: Time.now.utc, local_zone: nil)
    new(text, now: now, local_zone: local_zone).result
  end

  # The machine's tz database zone, from TZ or /etc/localtime.
  def self.local_zone_name
    from_env = ENV.fetch("TZ", "").delete_prefix(":")
    return from_env unless from_env.empty?

    File.readlink("/etc/localtime")[%r{zoneinfo/(.+)\z}, 1]
  rescue SystemCallError
    nil
  end

  def initialize(text, now:, local_zone:)
    @text = text.to_s
    @now = now.getutc
    @local_zone = local_zone
    @words = normalize(@text).split
  end

  def result
    zone_word = take_zone
    day = take_day
    clocks = take_clock
    fail_with("didn't understand #{@words.join(" ").inspect}") if
      @words.any?
    resolve(zone_word, day, clocks)
  end

  private

  def normalize(text)
    text.downcase.
      sub(/(\d{4}-\d{2}-\d{2})t(?=\d)/, '\1 ').
      gsub(/(\d)\s+(am|pm)\b/, '\1\2').
      gsub(/(\d)z\b/, '\1 z').
      gsub(/(\d:\d{2})([+-]\d)/, '\1 \2').
      gsub(/\bday after tomorrow\b/, "day_after_tomorrow").
      gsub(/\bat\b/, " ")
  end

  def fail_with(message)
    raise(Error.new("Bad deploy time #{@text.strip.inspect}: #{message} " \
                    "(#{EXAMPLES})."))
  end

  def take_zone
    found = @words.select { |word| zone_word?(word) }
    fail_with("more than one time zone") if found.size > 1
    @words -= found
    found.first
  end

  def zone_word?(word)
    ALWAYS.key?(word) || ABBREVIATIONS.key?(word) || word.match?(OFFSET) ||
      (word.include?("/") && iana_name(word))
  end

  def iana_name(word)
    TZInfo::Timezone.all_identifiers.find { |id| id.casecmp?(word) }
  end

  # :today, :tomorrow, a Date, a weekday index, or nil.
  def take_day
    days = @words.filter_map { |word| [word, day_for(word)] if day_for(word) }
    fail_with("more than one day") if days.size > 1
    return nil if days.empty?

    @words.delete(days.first.first)
    days.first.last
  end

  def day_for(word)
    case word
    when "today" then 0
    when "tomorrow" then 1
    when "day_after_tomorrow" then 2
    when /\A\d{4}-\d{2}-\d{2}\z/ then date(word)
    else weekday(word)
    end
  end

  def date(word)
    Date.iso8601(word)
  rescue Date::Error
    fail_with("#{word} is not a date")
  end

  def weekday(word)
    return nil if word.length < 3

    index = WEEKDAYS.index { |name| name.start_with?(word) }
    index && { weekday: index }
  end

  # [[hour, min], ...] -- two candidates when am/pm is left open.
  def take_clock
    fail_with("no time of day") if @words.empty?
    clocks = clocks_for(@words.first)
    fail_with("didn't understand #{@words.first.inspect}") unless clocks
    @words.shift
    clocks
  end

  def clocks_for(word)
    return [[12, 0]] if word == "noon"
    return [[0, 0]] if word == "midnight"

    match = CLOCK.match(word)
    return nil unless match

    hour = match[:hour].to_i
    min = match[:min].to_i
    fail_with("#{word} is not a time") if hour > 23 || min > 59
    candidates(match, hour, min)
  end

  def candidates(match, hour, min)
    if match[:half]
      fail_with("#{match} is not a time") unless (1..12).cover?(hour)
      return [[(hour % 12) + (match[:half] == "pm" ? 12 : 0), min]]
    end
    return [[hour, min]] if match[:hour].start_with?("0") || hour > 12

    [[hour % 12, min], [(hour % 12) + 12, min]]
  end

  def resolve(zone_word, day, clocks)
    zones_for(zone_word).each do |name, zone|
      time = pick(zone, day, clocks)
      return Result.new(time: time, zone: name) if
        abbreviation_fits?(zone_word, zone, time)
    end
    fail_with(misused_abbreviation(zone_word, day, clocks))
  end

  # [[label, zone], ...]; several only for an abbreviation used by more
  # than one zone.
  def zones_for(word)
    return [local_zone] if word.nil?
    return [[always_label(word), zone(ALWAYS[word])]] if ALWAYS.key?(word)
    if ABBREVIATIONS.key?(word)
      return ABBREVIATIONS[word].map { |name| [word.upcase, zone(name)] }
    end
    return [[word, fixed_zone(word)]] if word.match?(OFFSET)

    name = iana_name(word)
    [[name, zone(name)]]
  end

  def always_label(word)
    name = ALWAYS[word]
    name == "Etc/UTC" ? "UTC" : "#{word} (#{name})"
  end

  def local_zone
    name = @local_zone || self.class.local_zone_name
    fail_with("can't tell this machine's time zone; add one") unless name
    ["#{name} (local)", zone(name)]
  end

  def zone(name)
    TZInfo::Timezone.get(name)
  rescue TZInfo::InvalidTimezoneIdentifier
    fail_with("unknown time zone #{name}")
  end

  def fixed_zone(word)
    match = OFFSET.match(word)
    seconds = (match[:hours].to_i * 3600) + (match[:mins].to_i * 60)
    FixedZone.new(offset: match[:sign] == "-" ? -seconds : seconds,
                  name: word)
  end

  def abbreviation_fits?(word, zone, time)
    return true unless ABBREVIATIONS.key?(word)

    zone.period_for_utc(time).abbreviation.casecmp?(word)
  end

  def misused_abbreviation(word, day, clocks)
    name = ABBREVIATIONS[word].first
    time = pick(zone(name), day, clocks)
    local = zone(name).to_local(time)
    "#{word.upcase} isn't in use on #{local.strftime("%Y-%m-%d")}; " \
      "#{name} is on #{local.zone} then"
  end

  # With no day, the first candidate after now; with a day, the first
  # candidate on it.
  def pick(zone, day, clocks)
    today = zone.to_local(@now).to_date
    return next_time(zone, today, clocks) if day.nil?

    date = date_for(zone, day, today, clocks)
    clocks.map { |hour, min| at(zone, date, hour, min) }.min
  end

  def next_time(zone, today, clocks)
    [today, today + 1].product(clocks).
      map { |date, (hour, min)| at(zone, date, hour, min) }.
      select { |time| time > @now }.min
  end

  def date_for(zone, day, today, clocks)
    case day
    when Integer then today + day
    when Date then day
    else next_weekday(zone, day[:weekday], today, clocks)
    end
  end

  # Today counts when its time is still ahead.
  def next_weekday(zone, index, today, clocks)
    date = today + ((index - today.wday) % 7)
    hour, min = clocks.first
    date == today && at(zone, date, hour, min) <= @now ? date + 7 : date
  end

  # A time skipped by a spring-forward change is an error; a repeated
  # fall-back hour takes its first occurrence.
  def at(zone, date, hour, min)
    wall = Time.utc(date.year, date.month, date.day, hour, min)
    zone.local_to_utc(wall, &:first)
  rescue TZInfo::PeriodNotFound
    fail_with(format("%<date>s %<hour>02d:%<min>02d doesn't exist in " \
                     "%<zone>s (the clocks skip it)",
                     date: date, hour: hour, min: min,
                     zone: zone.identifier))
  end
end
