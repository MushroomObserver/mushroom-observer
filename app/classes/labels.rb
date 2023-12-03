# frozen_string_literal: true

require "rtf"

# Format observations as fancy labels in RTF format.
class Labels
  PARAGRAPH_PREFIX = "\\pard\\plain \\s0\\dbch\\af8\\langfe1081\\dbch\\af8" \
                     "\\afs24\\alang1081\\ql\\keep\\nowidctlpar\\sb0\\sa720" \
                     "\\ltrpar\\hyphpar0\\aspalpha\\cf0\\loch\\f6\\fs24" \
                     "\\lang1033\\kerning1\\ql\\tx4320"
  PARAGRAPH_SUFFIX = "\\par "

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
    File.read(MO.label_rtf_header_file) + format_observations + "}"
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
    add_observer_if_necessary
    add_sequences
    add_projects
    add_species_lists
    add_notes
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
    nums = collection_numbers + herbarium_records + [mo_number]
    @para << nums.join(" / ")
    @para << " #{specimen_available}" if nums.length == 1
    @para.line_break
  end

  def mo_number
    "MO #{@obs.id}"
  end

  def specimen_available
    @obs.specimen ? "(specimen available)" : "(no specimen)"
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
    italic = false
    @para.bold do |bold|
      @obs.name.display_name.gsub("**", "").split("__").each do |part|
        if part.present?
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
    @para << @obs.place_name
    @para.line_break
  end

  # --------------------

  def add_gps
    return unless @obs.lat.present? || @obs.alt.present?

    label("Coordinates")
    @para << format_lat_long
    @para << format_alt
    @para.line_break
  end

  def format_lat_long
    loc = @obs.location
    if @obs.lat.present?
      "#{format_lat(@obs.lat)} #{format_long(@obs.long)}"
    elsif loc.present?
      n = format_lat(loc.north)
      s = format_lat(loc.south)
      e = format_lat(loc.east)
      w = format_lat(loc.west)
      "#{s}–#{n} #{w}–#{e}"
    end
  end

  def format_alt
    loc = @obs.location
    if @obs.alt.present?
      ", #{@obs.alt} m"
    elsif loc&.low.present?
      if loc.high.present? && loc.low < loc.high
        ", #{loc.low}–#{loc.high} m"
      else
        ", #{loc.low} m"
      end
    end
  end

  def format_lat(val)
    val = val.round(1) unless coordinates_visible?
    val.negative? ? "#{-val}°S" : "#{val}°N"
  end

  def format_long(val)
    val = val.round(1) unless coordinates_visible?
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
  def add_observer_if_necessary
    observer = @obs.user.name || @obs.user.login
    collector = @obs.collection_numbers.first&.name
    return if collector == observer

    label("Observer")
    @para << observer
    @para.line_break
  end

  # --------------------

  # Sequence accession numbers if present.
  def add_sequences
    return unless @obs.sequences.any?

    label("Sequences")
    @para << @obs.sequences.map do |seq|
      "#{seq.locus} #{seq.archive} #{seq.accession}".strip_squeeze
    end.join(" / ")
    @para.line_break
  end

  # --------------------

  # Projects if attached to any.
  def add_projects
    return unless @obs.projects.any?

    label("Projects")
    @para << @obs.projects.map(&:title).join(" / ")
    @para.line_break
  end

  # --------------------

  # Species lists if attached to any.
  def add_species_lists
    return unless @obs.species_lists.any?

    label("Species Lists")
    @para << @obs.species_lists.map(&:title).join(" / ")
    @para.line_break
  end

  # --------------------

  # Any notes fields that are present.
  def add_notes
    @obs.notes.each do |key, val|
      next if val.blank?

      if key == Observation.other_notes_key
        label("Notes")
      else
        label(key.to_s.tr("_", " "))
      end
      @para << val
      @para.line_break
    end
  end
end
