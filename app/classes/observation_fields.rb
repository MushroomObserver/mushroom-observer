# frozen_string_literal: true

# Handles the creation of label fields from an observation
class ObservationFields
  attr_reader :observation

  def initialize(observation)
    @observation = observation
  end

  # Returns an array of LabelField objects for the observation
  def label_fields
    field_list = [
      create_field("ID", id_value),
      create_name_field("Name", observation.name.display_name_brief_authors),
      create_field("Location", observation.where),
      create_field("GPS", gps_value),
      create_field("Date", date_value),
      create_field("Collector", collector_value)
    ]
    # Remove any nil fields and return
    field_list.compact
  end

  def mo_url(observation)
    field_slip = observation.field_slips.first
    if field_slip
      code = field_slip.code
      [code, "https://mushroomobserver.org/qr/#{code}"]
    else
      id = observation.id
      [id, "https://mushroomobserver.org/observations/#{id}"]
    end
  end

  # Returns QR code fields for the observation
  def qr_fields
    qr_list = []

    # Add Mushroom Observer URL if observation has mo_id
    id, url = mo_url(observation)
    qr_list << QRCodeField.new("MO: #{id}", url)

    # Add iNaturalist URL if observation has inat_id
    inat_id = observation.inat_id
    if inat_id
      inat_url = "https://www.inaturalist.org/observations/#{inat_id}"
      qr_list << QRCodeField.new("iNat: #{inat_id}", inat_url)
    end

    qr_list
  end

  private

  def create_field(name, value)
    return nil if value.nil? || value.to_s.strip.empty?

    LabelField.new(name, value)
  end

  def create_name_field(name, value)
    return nil if value.nil? || value.to_s.strip.empty?

    NameField.new(name, value)
  end

  def id_value
    ids = herbarium_records + collection_numbers
    ids.join(" / ")
  end

  def herbarium_records
    observation.herbarium_records.
      select { |rec| rec.herbarium && rec.herbarium.personal_user_id.nil? }.
      map do |rec|
        "#{rec.herbarium.code || rec.herbarium.name} #{rec.accession_number}"
      end
  end

  def collection_numbers
    observation.collection_numbers.map { |num| "#{num.name} #{num.number}" }
  end

  def gps_value
    if observation.lat.present?
      return "#{format_lat(observation.lat)} #{format_lng(observation.lng)}"
    end

    loc_gps_value
  end

  def loc_gps_value
    loc = observation.location
    return if loc.blank?

    n = format_lat(loc.north, 3)
    s = format_lat(loc.south, 3)
    e = format_lng(loc.east, 3)
    w = format_lng(loc.west, 3)
    "#{s}–#{n} #{w}–#{e}"
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
    observation.user_id == User.current_id ||
      !observation.gps_hidden ||
      Project.admin_power?(observation, User.current)
  end

  def collector_value
    notes_collector || collection_number_collector || observer
  end

  def notes_collector
    notes_collector = observation.notes[:Collector]
    return unless notes_collector

    collector_identifier = extract_user_string_regex(notes_collector)
    user = User.find_by(login: collector_identifier)
    user&.name || collector_identifier
  end

  def extract_user_string_regex(input)
    match = input.match(/\A_user (.+)_\z/)
    match ? match[1] : input
  end

  def collection_number_collector
    observation.collection_numbers.first&.name
  end

  def observer
    observation.user.name
  end

  def date_value
    observation.when.strftime("%B %d, %Y")
  end
end
