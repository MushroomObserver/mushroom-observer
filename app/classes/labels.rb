# frozen_string_literal: true

require("rtf")

# Format observations as fancy labels in RTF format.
class Labels
  PARAGRAPH_PREFIX = "\\pard\\plain \\s0\\dbch\\af8\\langfe1081\\dbch\\af8" \
                     "\\afs24\\alang1081\\ql\\keep\\nowidctlpar\\sb0\\sa720" \
                     "\\ltrpar\\hyphpar0\\aspalpha\\cf0\\loch\\f6\\fs24" \
                     "\\lang1033\\kerning1\\ql\\tx4320"

  PARAGRAPH_SUFFIX = "\\par "
  MAX_LENGTH = 50

  attr_accessor :query
  attr_accessor :document

  def initialize(query)
    @query = query
    @document = RTF::Document.new(RTF::Font::SWISS)
  end

  # --------------------
  # These are all things expected by ObserverController#render_report.

  def header
    {}
  end

  def mime_type
    "application/rtf"
  end

  def encoding
    "UTF-8"
  end

  def filename
    "labels_#{query.id&.alphabetize}.rtf"
  end

  def body
    "#{File.read(MO.label_rtf_header_file)}#{format_observations}}"
  end

  # --------------------
  private

  def observations
    query.results(include: [:user, :name, :location, :sequences, :projects,
                            :species_lists, :collection_numbers,
                            { herbarium_records: :herbarium }])
  end

  def format_observations
    observations.map { |obs| format_observation(obs) }.join
  end

  def format_observation(obs)
    @para = RTF::CommandNode.new(document, PARAGRAPH_PREFIX, PARAGRAPH_SUFFIX)
    @obs = obs
    add_number
    add_name
    add_location
    add_gps
    add_date
    add_collector_or_observer
    @para.to_rtf
  end

  # RTF class doesn't support smallcaps, but it's really easy.
  def label(str)
    node = RTF::CommandNode.new(@para, "\\rtlch \\ltrch\\scaps\\loch")
    node.underline do |node2|
      node2.bold { |node3| node3 << str }
    end
    node << ": "
    @para.store(node)
  end

  # --------------------

  # Collector's number, e.g.: "John Doe 1234 / MO 56789"
  def add_number
    label("Number")
    nums = collection_numbers + herbarium_records + mo_number + inat_number
    @para << nums.join(" / ")
    @para.line_break
  end

  def mo_number
    ["MO #{@obs.id}"]
  end

  def inat_number
    @obs.inat_id ? ["iNat #{@obs.inat_id}"] : []
  end

  def collection_numbers
    @obs.collection_numbers.map { |num| "#{num.name} #{num.number}" }
  end

  def herbarium_records
    @obs.herbarium_records.
      select { |rec| rec.herbarium && rec.herbarium.personal_user_id.nil? }.
      map do |rec|
        "#{rec.herbarium.code || rec.herbarium.name} #{rec.accession_number}"
      end
  end

  # --------------------

  # Mushroom name, in bold and italic.
  def add_name
    label("Name")
    str = @obs.name.display_name_brief_authors.gsub("**", "")
    italic = false
    @para.bold do |bold|
      str.split("__").each do |part|
        unless part.empty?
          if italic
            bold.italic { |i| i << part } if part.present?
          else
            bold << part
          end
        end
        italic = !italic
      end
    end
    @para.line_break
  end

  # --------------------

  def add_location
    label("Location")
    reduce_long_strings(@obs.place_name).each do |line|
      @para << line
      @para.line_break
    end
  end

  # --------------------

  def add_gps
    label("GPS")
    @para << format_lat_lng
    @para << format_alt
    @para.line_break
  end

  def format_lat_lng
    loc = @obs.location
    if @obs.lat.present?
      "#{format_lat(@obs.lat)} #{format_lng(@obs.lng)}"
    elsif loc.present?
      n = format_lat(loc.north, 3)
      s = format_lat(loc.south, 3)
      e = format_lng(loc.east, 3)
      w = format_lng(loc.west, 3)
      "#{s}–#{n} #{w}–#{e}"
    end
  end

  def format_alt
    return ", #{@obs.alt.round(0)} m" if @obs.alt.present?

    format_loc_alt(@obs.location)
  end

  def format_loc_alt(loc)
    return unless loc

    low = loc.low
    high = loc.high
    if low.present?
      if high.present? && low < high
        ", #{low.round(0)}–#{high.round(0)} m"
      else
        ", #{low.round(0)} m"
      end
    elsif high.present?
      ", #{high.round(0)} m"
    end
  end

  def format_lat(val, precision = 4)
    val = if coordinates_visible?
            val.round(precision)
          else
            val.round(1)
          end
    val.negative? ? "#{-val}°S" : "#{val}°N"
  end

  def format_lng(val, precision = 4)
    val = if coordinates_visible?
            val.round(precision)
          else
            val.round(1)
          end
    val.negative? ? "#{-val}°W" : "#{val}°E"
  end

  def coordinates_visible?
    @obs.user_id == User.current_id ||
      !@obs.gps_hidden ||
      Project.admin_power?(@obs, User.current)
  end

  # --------------------

  # Date in format: "5 Dec 2021".
  def add_date
    label("Date")
    @para << @obs.when.strftime("%e %b %Y").strip
    @para.line_break
  end

  # --------------------

  # Observer's name if different from collector's name.
  def add_collector_or_observer
    if collector
      label("Collector")
      @para << collector
    end

    observer = @obs.user.name || @obs.user.login
    return if collector == observer

    @para << "  " if collector
    label("Observer")
    @para << observer
    @para.line_break
  end

  def collector
    @collector ||= calc_collector
  end

  def calc_collector
    notes_collector = @obs.notes[:Collector]
    return @obs.collection_numbers.first&.name unless notes_collector

    collector_identifier = extract_user_string_regex(notes_collector)
    user = User.find_by(login: collector_identifier)
    user&.name || collector_identifier
  end

  def extract_user_string_regex(input)
    match = input.match(/\A_user (.+)_\z/)
    match ? match[1] : input
  end

  def reduce_long_strings(str)
    len = str.length
    return [str] if len <= MAX_LENGTH

    split = find_last_space_or_comma_before_nth(str, MAX_LENGTH)
    return [str[..split], str[(split + 1)..]] if len - split <= MAX_LENGTH

    if len > 2 * MAX_LENGTH
      ["#{str[..MAX_LENGTH]}...", str[-MAX_LENGTH..]]
    else
      [str[..MAX_LENGTH], str[(MAX_LENGTH + 1)..]]
    end
  end

  def find_last_space_or_comma_before_nth(string, index)
    return nil if index <= 0 || index > string.length

    substring = string[0, index]
    substring.rindex(/[ ,]/)
  end
end
