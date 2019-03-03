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
#  == Class methods
#
#  Herbarium.primer::       List of names to prime autocompleter.
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
  has_and_belongs_to_many :curators, class_name: "User",
                                     join_table: "herbaria_curators"

  # If this is a user's personal herbarium (there should only be one?) then
  # personal_user_id is set to mark whose personal herbarium it is.
  belongs_to :personal_user, class_name: "User"

  # Used by create/edit form.
  attr_accessor :place_name
  attr_accessor :personal
  attr_accessor :personal_user_name

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

  def merge(that)
    return that if that == self

    this = self
    [:code, :location, :email, :mailing_address].each do |var|
      this.merge_field(that, var)
    end
    this.merge_notes(that)
    this.personal_user_id ||= that.personal_user_id
    this.save
    this.merge_associatied_records(that)
    that.destroy
    this
  end

  def merge_field(that, var)
    this = self
    val1 = this.send(var)
    val2 = that.send(var)
    return if val1.present?

    this.send(:"#{var}=", val2)
  end

  def merge_notes(that)
    this   = self
    notes1 = this.description
    notes2 = that.description
    if notes1.blank?
      this.description = notes2
    elsif notes2.present?
      this.description = "#{notes1}\n\n" \
                         "[Merged at #{Time.now.utc.web_time}]\n\n" +
                         notes2
    end
  end

  def merge_associatied_records(that)
    this = self
    this.curators          += that.curators - this.curators
    this.herbarium_records += that.herbarium_records - this.herbarium_records
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
