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
  MCP_COLLECTIONS = [
    "PH", # Academy of Natural Sciences of Drexel University
    "ACAD", # Acadia University, E. C. Smith Herbarium
    "CHSC", # Ahart Herbarium, CSU Chico - Mycological Collection
    "N/A", # Atlas of Living Australia specimen-based fungal data
    "BMSC", # Bamfield Marine Science Centre
    "BISH", # Bishop Museum, Herbarium Pacificum
    "BRIT", # Botanical Research Institute of Texas
    "BDWR", # Bridgewater College Herbarium
    "BRU", # Brown University Herbarium
    "HSC-F", # Cal Poly Humboldt Fungarium
    "CDA-Fungi", # California Department of Food and Agriculture - Fungi
    "HAY", # California State University East Bay Fungarium
    "AAFC-DAOM", # Canadian National Mycological Herbarium
    "WSP", # Charles Gardner Shaw Mycological Herbarium, Washington State University
    "CHRB", # Chrysler Herbarium - Mycological Collection
    "CLEMS", # Clemson University Herbarium
    "HCOA", # College of the Atlantic, Acadia National Park Herbarium
    "CUP", # Cornell University Plant Pathology Herbarium
    "CBBG", # Crested Butte Botanic Gardens
    "DEWV", # Davis & Elkins College Herbarium
    "DBG-DBG", # Denver Botanic Gardens, Sam Mitchel Herbarium of Fungi
    "DUKE", # Duke University Herbarium Fungal Collection
    "EIU", # Eastern Illinois University
    "EWU", # Eastern Washington University
    "QCAM", # Ecuador Fungi data from FungiWebEcuador
    "TAM", # Estonian Museum of Natural History
    "BAFC-H", # Facultad de Ciencias Exactas y Naturales
    "F", # Field Museum of Natural History
    "FNL", # Foray Newfoundland and Labrador Fungarium
    "FLD", # Fort Lewis College Herbarium
    "GLM", # Fungal Collection at the Senckenberg Museum für Naturkunde Görlitz
    "M", # Fungal Collections at the Botanische Staatssammlung München
    "KR", # Fungus Collections at Staatliches Museum für Naturkunde Karlsruhe
    "FH", # Harvard University, Farlow Herbarium
    "FR", # Herbarium Senckenbergianum
    "IND", # Indiana University
    "TAAM", # Institute of Agricultural and Environmental Sciences of the Estonian University of Life Sciences (TAAM)
    "EAA", # Estonian University of Life Sciences (EAA)
    "INEP-F", # Institute of the Industrial Ecology Problems of the North of Kola Science Center of the Russian Academy of Sciences.
    "PACA", # Instituto Anchietano de Pesquisas/UNISINOS
    "USU-UTC", # Intermountain Herbarium (fungi, not lichens), Utah State University
    "ICMP", # International Collection of Microorganisms from Plants
    "ISC", # Iowa State University, Ada Hayden Herbarium
    "SUCO", # Jewell and Arline Moss Settle Herbarium at SUNY Oneonta
    "LSUM-Fungi", # Louisiana State University, Bernard Lowy Mycological Herbarium
    "MUHW", # Marshall University Herbarium - Fungi
    "BR", # Meise Botanic Garden Herbarium
    "MU", # Miami University, Willard Sherman Turrell Herbarium
    "MSC", # Michigan State University Herbarium non-lichenized fungi
    "MOR", # Morton Arboretum
    "CORD", # Museo Botánico Córdoba Fungarium
    "CR", # Museo Nacional de Costa Rica, specimen-based
    "PC", # Muséum National d'Histoire Naturelle
    "MNA", # Museum of Northern Arizona
    "IBUNAM-MEXU:FU", # National Herbarium of Mexico Fungal Collection (Hongos del Herbario Nacional de México)
    "TNS-F", # National Museum of Nature and Science - Japan
    "NMC-FUNGI", # National Mushroom Centre
    "UT-M", # Natural History Museum of Utah Fungarium
    "L", # Naturalis Biodiversity Center
    "NBM", # New Brunswick Museum
    "NY", # New York Botanical Garden
    "NYS", # New York State Museum Mycology Collection
    "PDD", # New Zealand Fungarium
    "NCSLG", # North Carolina State University, Larry F. Grand Mycological Herbarium
    "OSC", # Oregon State University Herbarium
    "OSC-Lichens", # Oregon State University Herbarium - Lichens
    "USFWS-PRR", # Patuxent Research Refuge - Maryland
    "PUR", # Purdue University, Arthur Fungarium
    "PUL", # Purdue University, Kriebel Herbarium
    "QFB", # René Pomerleau Herbarium
    "E", # Royal Botanic Garden Edinburgh
    "TRTC", # Royal Ontario Museum Fungarium
    "TAES", # S.M. Tracy Herbarium Texas A&M University
    "SFSU", # San Francisco State University, Harry D. Thiers Herbarium
    "SBBG", # Santa Barbara Botanic Garden
    "LJF", # Slovenian Fungal Database (Mikoteka in herbarij Gozdarskega inštituta Slovenije), specimen-based
    "CORT", # State University of New York College at Cortland
    "SYRF", # State University of New York, SUNY College of Environmental Science and Forestry Herbarium
    "SWAT", # Swat University Fungarium
    "S", # Swedish Museum of Natural History
    "TALL", # Tallinn Botanic Garden
    "IBUG", # Universidad de Guadalajara
    "CMMF", # Université de Montréal, Cercle des Mycologues de Montréal Fungarium
    "UACCC", # University of Alabama Chytrid Culture Collection
    "ARIZ", # University of Arizona, Gilbertson Mycological Herbarium, specimen-based
    "UARK", # University of Arkansas Fungarium
    "UBC", # University of British Columbia Herbarium
    "UC", # University of California Berkeley, University Herbarium
    "UCSC", # University of California Santa Cruz Fungal Herbarium
    "IRVC", # University of California, Irvine Fungarium
    "LA", # University of California, Los Angeles
    "FTU", # University of Central Florida
    "CSU", # University of Central Oklahoma Herbarium
    "CINC", # University of Cincinnati, Margaret H. Fulford Herbarium - Fungi
    "C", # University of Copenhagen
    "FLAS", # University of Florida Herbarium
    "GAM", # University of Georgia, Julian H. Miller Mycological Herbarium
    "GB", # University of Gothenburg
    "HAW-F", # University of Hawaii, Joseph F. Rock Herbarium
    "ILL", # University of Illinois Herbarium
    "ILLS", # University of Illinois, Illinois Natural History Survey Fungarium
    "KANU-KU-F", # University of Kansas, R. L. McGregor Herbarium
    "MAINE", # University of Maine, Richard Homola Mycological Herbarium
    "WIN", # University of Manitoba
    "MICH", # University of Michigan Herbarium
    "MIN", # University of Minnesota, Bell Museum of Natural History Herbarium Fungal Collection
    "MISS", # University of Mississippi
    "MONTU", # University of Montana Herbarium
    "NEB", # University of Nebraska State Museum, C.E. Bessey Herbarium - Fungi
    "UNM-Fungi", # University of New Mexico Herbarium Mycological Collection
    "UNCA-UNCA", # University of North Carolina Asheville
    "NCU-Fungi", # University of North Carolina at Chapel Hill Herbarium: Fungi
    "O", # University of Oslo, Natural History Museum Fungarium
    "URV", # University of Richmond
    "USAM", # University of South Alabama Herbarium
    "USCH-Fungi", # University of South Carolina, A. C. Moore Herbarium Fungal Collection
    "USF", # University of South Florida Herbarium - Fungi including lichens
    "TU", # University of Tartu Natural History Museum
    "TENN-F", # University of Tennessee Fungal Herbarium
    "UCHT-F", # University of Tennessee, Chattanooga
    "TEX", # University of Texas Herbarium
    "VT", # University of Vermont, Pringle Herbarium, Macrofungi
    "WTU", # University of Washington Herbarium
    "UWAL", # University of West Alabama Fungarium
    "WIS", # University of Wisconsin-Madison Herbarium
    "UWSP", # University of Wisconsin-Stevens Point Herbarium
    "RMS", # University of Wyoming, Wilhelm G. Solheim Mycological Herbarium
    "UPS-BOT", # Uppsala University, Museum of Evolution
    "USAC-USCG Hongos", # Usac, Cecon, Herbario USCG Hongos
    "CFMR", # USDA Forest Service, Center for Forest Mycology Research
    "FPF", # USDA Forest Service, Rocky Mountain Research Station
    "BPI", # USDA United States National Fungus Collections
    "VSC", # Valdosta State University Herbarium
    "VPI", # Virginia Tech University, Massey Herbarium - Fungi
    "YSU-F" # Yugra State University Fungarium, specimen-based
  ].freeze
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
end
