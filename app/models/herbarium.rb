# frozen_string_literal: true

#
#  = Herbarium Model
#
#  Represents an herbarium, either an official institution like NYBG or a more
#  informal entity such as a user's personal herbarium.
#
#  == Attributes
#
#  id::               Locally unique numerical id, starting at 1.
#  created_at::       Date/time this record was created.
#  updated_at::       Date/time this record was last updated.
#  personal_user_id:: User if it is a personal herbarium (optional).
#                     Each User can only have at most one personal herbarium.
#  code::             Official code (e.g., "NY" for NYBG, optional).
#  name::             Name of herbarium. (must be present and unique)
#  format_name::      "Name (CODE)", for compatibility with other models.
#  email::            Email address for inquiries (optional now).
#  location_id::      Location of herbarium (optional).
#  mailing_address::  Postal address for sending specimens to (optional).
#  description::      Random notes (optional).
#
#  == Instance methods
#
#  herbarium_records::      HerbariumRecord(s) belonging to this Herbarium.
#  curators::               User(s) allowed to add records (optional).
#                           If no curators, then anyone can edit this record.
#                           If there are curators, then edit is restricted
#                           to just those users.
#  can_edit?(user)::        Check if a User has permission to edit.
#  curator?(user)::         Check if a User is a curator.
#  add_curator(user)::      Add User as a curator unless already is one.
#  delete_curator(user)::   Remove User from curators.
#  web_searchable?::        Are its digital records searchable via the internet?
#  mcp_searchable?          Are its digital records searchable via MyCoPortal?
#  sort_name::              Stripped-down version of name for sorting.
#  merge(other_herbarium):: merge other_herbarium into this one
#
#  == Callbacks
#
#  notify curators::  Email curators of Herbarium when non-curator adds an
#                     HerbariumRecord to an Herbarium.  Called after create.
#
################################################################################

class Herbarium < AbstractModel
  has_many :herbarium_records, dependent: :destroy
  belongs_to :location

  has_many :herbarium_curators, dependent: :destroy
  has_many :curators, through: :herbarium_curators, source: :user

  # If this is a user's personal herbarium (there should only be one?) then
  # personal_user_id is set to mark whose personal herbarium it is.
  belongs_to :personal_user, class_name: "User"

  # Used by create/edit form.
  attr_accessor :place_name, :personal, :personal_user_name

  # Herbaria whose collections are searchable via MyCoPortal.
  # https://www.mycoportal.org/portal/collections/index.php
  # rubocop:disable Layout/LineLength
  MCP_COLLECTIONS = {
    "PH" => nil, # Academy of Natural Sciences of Drexel University
    "ACAD" => nil, # Acadia University, E. C. Smith Herbarium
    "CHSC" => nil, # Ahart Herbarium, CSU Chico - Mycological Collection
    "N/A" => nil, # Atlas of Living Australia specimen-based fungal data
    "BMSC" => nil, # Bamfield Marine Science Centre
    "BISH" => nil, # Bishop Museum, Herbarium Pacificum
    "BRIT" => nil, # Botanical Research Institute of Texas
    "BDWR" => nil, # Bridgewater College Herbarium
    "BRU" => nil, # Brown University Herbarium
    "HSC-F" => nil, # Cal Poly Humboldt Fungarium
    "CDA-Fungi" => nil, # California Department of Food and Agriculture - Fungi
    "HAY" => nil, # California State University East Bay Fungarium
    "AAFC-DAOM" => nil, # Canadian National Mycological Herbarium
    "WSP" => nil, # Charles Gardner Shaw Mycological Herbarium, Washington State University
    "CHRB" => nil, # Chrysler Herbarium - Mycological Collection
    "CLEMS" => nil, # Clemson University Herbarium
    "HCOA" => nil, # College of the Atlantic, Acadia National Park Herbarium
    "CUP" => nil, # Cornell University Plant Pathology Herbarium
    "CBBG" => nil, # Crested Butte Botanic Gardens
    "DEWV" => nil, # Davis & Elkins College Herbarium
    "DBG-DBG" => nil, # Denver Botanic Gardens, Sam Mitchel Herbarium of Fungi
    "DUKE" => nil, # Duke University Herbarium Fungal Collection
    "EIU" => nil, # Eastern Illinois University
    "EWU" => nil, # Eastern Washington University
    "QCAM" => nil, # Ecuador Fungi data from FungiWebEcuador
    "TAM" => nil, # Estonian Museum of Natural History
    "BAFC-H" => nil, # Facultad de Ciencias Exactas y Naturales
    "F" => nil, # Field Museum of Natural History
    "FNL" => nil, # Foray Newfoundland and Labrador Fungarium
    "FLD" => nil, # Fort Lewis College Herbarium
    "GLM" => nil, # Fungal Collection at the Senckenberg Museum für Naturkunde Görlitz
    "M" => nil, # Fungal Collections at the Botanische Staatssammlung München
    "KR" => nil, # Fungus Collections at Staatliches Museum für Naturkunde Karlsruhe
    "FH" => nil, # Harvard University, Farlow Herbarium
    "FR" => nil, # Herbarium Senckenbergianum
    "IND" => nil, # Indiana University
    "TAAM" => nil, # Institute of Agricultural and Environmental Sciences of the Estonian University of Life Sciences (TAAM)
    "EAA" => nil, # Estonian University of Life Sciences (EAA)
    "INEP-F" => nil, # Institute of the Industrial Ecology Problems of the North of Kola Science Center of the Russian Academy of Sciences.
    "PACA" => nil, # Instituto Anchietano de Pesquisas/UNISINOS
    "USU-UTC" => nil, # Intermountain Herbarium (fungi, not lichens), Utah State University
    "ICMP" => nil, # International Collection of Microorganisms from Plants
    "ISC" => nil, # Iowa State University, Ada Hayden Herbarium
    "SUCO" => nil, # Jewell and Arline Moss Settle Herbarium at SUNY Oneonta
    "LSUM-Fungi" => nil, # Louisiana State University, Bernard Lowy Mycological Herbarium
    "MUHW" => nil, # Marshall University Herbarium - Fungi
    "BR" => nil, # Meise Botanic Garden Herbarium
    "MU" => nil, # Miami University, Willard Sherman Turrell Herbarium
    "MSC" => nil, # Michigan State University Herbarium non-lichenized fungi
    "MOR" => nil, # Morton Arboretum
    "CORD" => nil, # Museo Botánico Córdoba Fungarium
    "CR" => nil, # Museo Nacional de Costa Rica, specimen-based
    "PC" => nil, # Muséum National d'Histoire Naturelle
    "MNA" => nil, # Museum of Northern Arizona
    "IBUNAM-MEXU:FU" => nil, # National Herbarium of Mexico Fungal Collection (Hongos del Herbario Nacional de México)
    "TNS-F" => nil, # National Museum of Nature and Science - Japan
    "NMC-FUNGI" => nil, # National Mushroom Centre
    "UT-M" => nil, # Natural History Museum of Utah Fungarium
    "L" => nil, # Naturalis Biodiversity Center
    "NBM" => nil, # New Brunswick Museum
    "NY" => nil, # New York Botanical Garden
    "NYS" => nil, # New York State Museum Mycology Collection
    "PDD" => nil, # New Zealand Fungarium
    "NCSLG" => nil, # North Carolina State University, Larry F. Grand Mycological Herbarium
    "OSC" => nil, # Oregon State University Herbarium
    "OSC-Lichens" => nil, # Oregon State University Herbarium - Lichens
    "USFWS-PRR" => nil, # Patuxent Research Refuge - Maryland
    "PUR" => nil, # Purdue University, Arthur Fungarium
    "PUL" => nil, # Purdue University, Kriebel Herbarium
    "QFB" => nil, # René Pomerleau Herbarium
    "E" => nil, # Royal Botanic Garden Edinburgh
    "TRTC" => nil, # Royal Ontario Museum Fungarium
    "TAES" => nil, # S.M. Tracy Herbarium Texas A&M University
    "SFSU" => nil, # San Francisco State University, Harry D. Thiers Herbarium
    "SBBG" => nil, # Santa Barbara Botanic Garden
    "LJF" => nil, # Slovenian Fungal Database (Mikoteka in herbarij Gozdarskega inštituta Slovenije), specimen-based
    "CORT" => nil, # State University of New York College at Cortland
    "SYRF" => nil, # State University of New York, SUNY College of Environmental Science and Forestry Herbarium
    "SWAT" => nil, # Swat University Fungarium
    "S" => nil, # Swedish Museum of Natural History
    "TALL" => nil, # Tallinn Botanic Garden
    "IBUG" => nil, # Universidad de Guadalajara
    "CMMF" => nil, # Université de Montréal, Cercle des Mycologues de Montréal Fungarium
    "UACCC" => nil, # University of Alabama Chytrid Culture Collection
    "ARIZ" => nil, # University of Arizona, Gilbertson Mycological Herbarium, specimen-based
    "UARK" => nil, # University of Arkansas Fungarium
    "UBC" => nil, # University of British Columbia Herbarium
    "UC" => nil, # University of California Berkeley, University Herbarium
    "UCSC" => nil, # University of California Santa Cruz Fungal Herbarium
    "IRVC" => nil, # University of California, Irvine Fungarium
    "LA" => nil, # University of California, Los Angeles
    "FTU" => nil, # University of Central Florida
    "CSU" => nil, # University of Central Oklahoma Herbarium
    "CINC" => nil, # University of Cincinnati, Margaret H. Fulford Herbarium - Fungi
    "C" => nil, # University of Copenhagen
    "FLAS" => nil, # University of Florida Herbarium
    "GAM" => nil, # University of Georgia, Julian H. Miller Mycological Herbarium
    "GB" => nil, # University of Gothenburg
    "HAW-F" => nil, # University of Hawaii, Joseph F. Rock Herbarium
    "ILL" => nil, # University of Illinois Herbarium
    "ILLS" => nil, # University of Illinois, Illinois Natural History Survey Fungarium
    "KANU-KU-F" => nil, # University of Kansas, R. L. McGregor Herbarium
    "MAINE" => nil, # University of Maine, Richard Homola Mycological Herbarium
    "WIN" => nil, # University of Manitoba
    "MICH" => nil, # University of Michigan Herbarium
    "MIN" => nil, # University of Minnesota, Bell Museum of Natural History Herbarium Fungal Collection
    "MISS" => nil, # University of Mississippi
    "MONTU" => nil, # University of Montana Herbarium
    "NEB" => nil, # University of Nebraska State Museum, C.E. Bessey Herbarium - Fungi
    "UNM-Fungi" => nil, # University of New Mexico Herbarium Mycological Collection
    "UNCA-UNCA" => nil, # University of North Carolina Asheville
    "NCU-Fungi" => nil, # University of North Carolina at Chapel Hill Herbarium: Fungi
    "O" => nil, # University of Oslo, Natural History Museum Fungarium
    "URV" => nil, # University of Richmond
    "USAM" => nil, # University of South Alabama Herbarium
    "USCH-Fungi" => nil, # University of South Carolina, A. C. Moore Herbarium Fungal Collection
    "USF" => nil, # University of South Florida Herbarium - Fungi including lichens
    "TU" => nil, # University of Tartu Natural History Museum
    "TENN-F" => nil, # University of Tennessee Fungal Herbarium
    "UCHT-F" => nil, # University of Tennessee, Chattanooga
    "TEX" => nil, # University of Texas Herbarium
    "VT" => nil, # University of Vermont, Pringle Herbarium, Macrofungi
    "WTU" => nil, # University of Washington Herbarium
    "UWAL" => nil, # University of West Alabama Fungarium
    "WIS" => nil, # University of Wisconsin-Madison Herbarium
    "UWSP" => nil, # University of Wisconsin-Stevens Point Herbarium
    "RMS" => nil, # University of Wyoming, Wilhelm G. Solheim Mycological Herbarium
    "UPS-BOT" => nil, # Uppsala University, Museum of Evolution
    "USAC-USCG Hongos" => nil, # Usac, Cecon, Herbario USCG Hongos
    "CFMR" => nil, # USDA Forest Service, Center for Forest Mycology Research
    "FPF" => nil, # USDA Forest Service, Rocky Mountain Research Station
    "BPI" => nil, # USDA United States National Fungus Collections
    "VSC" => nil, # Valdosta State University Herbarium
    "VPI" => nil, # Virginia Tech University, Massey Herbarium - Fungi
    "YSU-F" => nil # Yugra State University Fungarium, specimen-based
  }.freeze
  # rubocop:enable Layout/LineLength

  def can_edit?(user = User.current)
    if personal_user_id
      personal_user_id == user.try(&:id)
    else
      curators.none? || curators.member?(user)
    end
  end

  def curator?(user)
    curators.member?(user)
  end

  def add_curator(user)
    curators.push(user) unless curator?(user)
  end

  def delete_curator(user)
    curators.delete(user)
  end

  def format_name
    code.blank? ? name : "#{name} (#{code})"
  end

  def unique_format_name
    "#{format_name} (#{id})"
  end

  def sort_name
    name.t.html_to_ascii.gsub(/\W+/, " ").strip_squeeze.downcase
  end

  def auto_complete_name
    code.blank? ? name : "#{code} - #{name}"
  end

  def owns_all_records?(user = User.current)
    herbarium_records.all? { |r| r.user_id == user.id }
  end

  def can_make_personal?(user = User.current)
    user && !user.personal_herbarium && owns_all_records?(user)
  end

  def can_merge_into?(other, user = User.current)
    return false if self == other
    # Target must be user's personal herbarium.
    return false if !user || !other || other.personal_user_id != user.id

    # User must own all the records attached to the one being deleted.
    herbarium_records.all? { |r| r.user_id == user.id }
  end

  # Info to include about each herbarium in merge requests.
  def merge_info
    num_cur = curators.count
    num_rec = herbarium_records.count
    "#{:HERBARIUM.l} ##{id}: #{name} [#{num_cur} curators, #{num_rec} records]"
  end

  def merge(src)
    return src if src == self

    dest = self
    [:code, :location, :email, :mailing_address].each do |var|
      dest.merge_field(src, var)
    end
    dest.merge_notes(src)
    dest.personal_user_id ||= src.personal_user_id
    dest.save
    dest.merge_associated_records(src)
    src.destroy
    dest
  end

  def merge_field(src, var)
    dest = self
    val1 = dest.send(var)
    val2 = src.send(var)
    return if val1.present?

    dest.send(:"#{var}=", val2)
  end

  def merge_notes(src)
    dest   = self
    notes1 = dest.description
    notes2 = src.description
    if notes1.blank?
      dest.description = notes2
    elsif notes2.present?
      dest.description = "#{notes1}\n\n" \
                         "[Merged at #{Time.now.utc.web_time}]\n\n" +
                         notes2
    end
  end

  def merge_associated_records(src)
    dest = self
    dest.curators          += src.curators - dest.curators
    dest.herbarium_records += src.herbarium_records - dest.herbarium_records
  end

  def self.find_by_code_with_wildcards(str)
    find_using_wildcards("code", str)
  end

  def self.find_by_name_with_wildcards(str)
    find_using_wildcards("name", str)
  end

  def web_searchable?
    mcp_searchable? || mycoportal_db.present?
  end

  def mcp_searchable?
    MCP_COLLECTIONS.key?(code)
  end

  def mcp_url(accession)
    base_url = "https://www.mycoportal.org/portal/collections/list.php"
    search_params =
      { catnum: strip_leading_code(accession), db: mycoportal_db,
        includeothercatnum: 1 }

    "#{base_url}?#{search_params.to_query}"
  end

  private

  def strip_leading_code(accession)
    accession.gsub(/"^#{code} "/, "")
  end
end
