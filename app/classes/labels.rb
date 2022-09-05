# frozen_string_literal: true

# Format observations as fancy labels in RTF format.
class Labels
  FUNDIS_HERBARIUM = "Fungal Diversity Survey".freeze

  attr_accessor :query
  attr_accessor :document

  def self.new(query)
    @query = query
    @document = RTF::Document.new
  end

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
    header + format_observations + footer
  end

  # ----------------------------------------------------------------------

  private

  def observations
    query.includes(:user, :name, :location, :sequences, :projects,
                   :herbarium_records, :collection_numbers).results
  end

  def header
    File.read(MO.label_rtf_header_file)
  end

  def footer
    "}"
  end

  def format_observations
    observations.map { |obs| format_observation(obs) }.join("")
  end

  def format_observation(obs)
    document.paragraph do |para|
      @para = para
      @obs = obs
      format_number
      format_name
      format_location
      format_date
      format_sequences
      format_project
      format_notes
    end.to_rtf
  end

  # RTF class doesn't support smallcaps, but it's really easy.
  def label(str)
    node = RTF::CommandNode.new(@para, "\\rtlch \\ltrch\\scaps\\loch")
    node << str
    @para.store(node)
  end

  # --------------------

  # Collector's number, e.g.: "John Doe 1234 / MO 56789"
  def format_number
    label("number")
    nums = collection_numbers + [mo_number] + [fundis_number]
    @para << nums.compact.join(" / ")
    @para.line_break
  end

  def collection_numbers
    @obs.collection_numbers.map { |num| "#{num.name} #{num.number}" }
  end

  def mo_number
    "MO ##{obs.id}"
  end

  def fundis_number
    return nil unless fundis_herbarium_id = fundis_herbarium&.id

    observation.herbarium_records.each do |rec|
      return "FunDiS ##{fundis_record.accession_number}" \
        if rec.herbarium_id == fundis_herbarium_id
    end
    nil
  end

  def fundis_herbarium
    # Stick it in a trivial array to ensure that the result is non-nil even
    # if there is no matching herbarium.  It's a kludge, but it works.
    (@@fundis_herbarium ||= [Herbarium.find_by(name: FUNDIS_HERBARIUM)]).first
  end

  # --------------------

  # Mushroom name, in bold and italic.
  def format_name
    label("name")
    italic = false
    @para.bold do |bold|
      @obs.name.display_name.gsub("**", "").split("__").each do |part|
        if italic
          bold.italic { |i| i << part } if part.present?
        else
          bold << part if part.present?
        end
        italic = !italic
      end
    end
    @para.line_break
  end

  # --------------------

  # Location (scientific order) + GPS.
  def format_location
    label("location")
    @para << Location.reverse_name(loc&.name || @obs.where)
    @para << format_lat_long
    @para << format_alt
    @para.line_break
  end

  def format_lat_long
    loc = @obs.location
    if @obs.lat.present?
      " – #{format_lat(@obs.lat)} #{format_long(@obs.long)}"
    elsif loc.present?
      n = format_lat(loc.north)
      s = format_lat(loc.south)
      e = format_lat(loc.east)
      w = format_lat(loc.west)
      " – #{s}–#{n} #{w}–#{e}"
    end
  end

  def format_alt
    loc = @obs.location
    if @obs.alt.present?
      ", #{@obs.alt} m"
    elsif loc&.low.present?
      if loc.low < loc.high
        ", #{loc.low}–#{loc.high} m"
      else
        ", #{loc.low} m"
      end
    end
  end

  def format_lat(v)
    v < 0 ? "#{-v}°S" : "#{v}°N"
  end

  def format_long(v)
    v < 0 ? "#{-v}°W" : "#{v}°E"
  end

  # --------------------

  # Date in format: "5 Dec 2021".
  def format_date
    label("date")
    @para << @obs.when.strftime("%D %b %Y")
    @para.line_break
  end

  # --------------------

  # Sequence accession numbers if present.
  def format_sequences
    return unless @obs.sequences.any?

    label("sequences")
    @para << @obs.sequences.map do |seq|
      "#{seq.locus} #{seq.archive} #{seq.accession}".strip_squeeze
    end.join(", ")
    @para.line_break
  end

  # --------------------

  # Projects if attached to any.
  def format_project
    return unless @obs.projects.any?

    label("project")
    @para << @obs.projects.map(&:title).join(", ")
    @para.line_break
  end

  # --------------------

  # Any notes fields that are present.
  def format_notes
    @obs.notes.each do |key, val|
      next unless val.present? && key != Observation.other_notes_key

      label(key)
      @para << val
      @para.line_break
    end
  end
end
