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
#  email::            Email address for inquiries (optional now).
#  location_id::      Location of herbarium (optional).
#  mailing_address::  Postal address for sending specimens to (optional).
#  description::      Random notes (optional).
#
#  == Class methods
#
#  Herbarium.primer::                 List of names to prime autocompleter.
#  Herbarium.default_specimen_label:: Format herbarium label.
#
#  == Instance methods
#
#  herbarium_records::      HerbariumRecord(s) belonging to this Herbarium.
#  curators::               User(s) allowed to add records (optional).
#                           If no curators, then anyone can edit this record.
#                           If there are curators, then edit is restricted
#                           to just those users.
#  can_edit?(user)::        Check if a User has permission to edit.
#  is_curator?(user)::      Check if a User is a curator.
#  add_curator(user)::      Add User as a curator unless already is one.
#  delete_curator(user)::   Remove User from curators.
#  herbarium_record_count:: Number of HerbariumRecord's at this Herbarium.
#  sort_name::              Stripped-down version of name for sorting.
#
#  == Callbacks
#
#  notify curators::  Email curators of Herbarium when non-curator adds an
#                     HerbariumRecord to an Herbarium.  Called after create.
#
################################################################################
class Herbarium < AbstractModel
  has_many :herbarium_records
  belongs_to :location
  has_and_belongs_to_many :curators, class_name: "User",
                                     join_table: "herbaria_curators"

  # If this is a user's personal herbarium (there should only be one?) then
  # personal_user_id is set to mark whose personal herbarium it is.
  belongs_to :personal_user, class_name: "User"

  # Used by create/edit form.
  attr_accessor :place_name
  attr_accessor :personal

  def can_edit?(user = User.current)
    curators.none? || curators.member?(user)
  end

  def is_curator?(user)
    curators.member?(user)
  end

  def add_curator(user)
    curators.push(user) unless is_curator?(user)
  end

  def delete_curator(user)
    curators.delete(user)
  end

  def herbarium_record_count
    herbarium_records.count
  end

  def sort_name
    name.t.strip_html.gsub(/\W+/, " ").strip_squeeze.downcase
  end

  # Info to include about each herbarium in merge requests.
  def merge_info
    num_cur = curators.count
    num_rec = herbarium_records.count
    "#{:HERBARIUM.l} ##{id}: #{name} [#{num_cur} curators, #{num_rec} records]"
  end

  def self.default_specimen_label(name, id)
    "#{name}: #{id || "?"}".strip_html
  end

  # Look at the most recent HerbariumRecord's the current User has created.
  # Return a list of the last 100 herbarium names used in those
  # HerbariumRecords that this user is a curator for.  This list is used to
  # prime Herbarium auto-completers. 
  def self.primer
    result = ""
    if User.current
      result = connection.select_values(%(
        SELECT DISTINCT h.name AS x
        FROM herbarium_records s, herbaria h, herbaria_curators c
        WHERE s.herbarium_id = h.id
        AND h.id = c.herbarium_id
        AND c.user_id = #{user_id}
        ORDER BY s.updated_at DESC
        LIMIT 100
      )).sort
    end
    result
  end
end
