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
  has_and_belongs_to_many :curators, class_name: "User",
                                     join_table: "herbaria_curators"

  # If this is a user's personal herbarium (there should only be one?) then
  # personal_user_id is set to mark whose personal herbarium it is.
  belongs_to :personal_user, class_name: "User"

  # Used by create/edit form.
  attr_accessor :place_name, :personal, :personal_user_name

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
