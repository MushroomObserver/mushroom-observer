# frozen_string_literal: true

#
#  = CollectionNumbers Model
#
#  Represents a voucher specimen's collector and number.  A single specimen
#  can potentially have more than one collection number in strange cases, but
#  usually it will be one-to-one.  However there is no object in MO which
#  represents a physical voucher collection / specimen.
#
#  CollectionNumber records are associated with Observation(s) (again possibly
#  more than one), and indirectly through them they are associated with
#  HerbariumRecord(s) and finally an Herbarium (or more than one).
#
#  In the typical case, when an observation with a physical voucher collection
#  is created, both one CollectionNumber and one HerbariumRecord (typically at
#  the user's personal herbarium) are also created.  When the specimen is sent
#  to another institution, a new HerbariumRecord will be created.  There is no
#  way at present to track in which physical Herbarium a physical specimen
#  actually resides.
#
#  Note that changing a CollectionNumber will automatically indirectly affect
#  any Observation associated with it.  However, note that if an
#  HerbariumRecord contains the collector's name and/or number (e.g. in the
#  user's personal herbarium's herbarium_label), this will not be changed
#  automatically.  The controller will have to check for this and make the
#  change to the HerbariumRecord(s) separately.
#
#  == Attributes
#
#  id::          Locally unique numerical id, starting at 1.
#  user_id::     Id of User who created this record.
#  created_at::  Date/time this record was created.
#  updated_at::  Date/time this record was last updated.
#  name::        Collector's full name, not necessarily same as creator.
#  number::      Collector's unique number (uniqueness not enforced).
#
#  == Class methods
#
#  None
#
#  == Instance methods
#
#  observations::    Observation's associated with this collection number.
#  add_observation:: Add CollectionNumber to Observation, log it and save.
#  format_name::     Both collector's name and number.
#  can_edit?::       Check if user can edit this record.
#
#  == Callbacks
#
#  None.
#
class CollectionNumber < AbstractModel
  require "arel-helpers"

  include ArelHelpers::ArelTable
  include ArelHelpers::JoinAssociation

  has_and_belongs_to_many :observations
  belongs_to :user

  before_update :log_update
  before_destroy :log_destroy

  def format_name
    "#{name} #{number}"
  end

  def format_name_was
    "#{name_was} #{number_was}"
  end

  def can_edit?(user = User.current)
    observations.any? { |obs| obs.user == user }
  end

  # Add this CollectionNumber to an Observation, make sure the observation
  # reports a specimen available, and log the action.
  def add_observation(obs)
    return if observations.include?(obs)

    observations.push(obs)
    obs.update(specimen: true) unless obs.specimen
    obs.log(:log_collection_number_added, name: format_name, touch: true)
  end

  # Remove this CollectionNumber from an Observation and log the action.
  def remove_observation(obs)
    return unless observations.include?(obs)

    observations.delete(obs)
    obs.reload.turn_off_specimen_if_no_more_records
    obs.log(:log_collection_number_removed, name: format_name, touch: true)
    destroy if observations.empty?
  end

  def log_update
    observations.each do |obs|
      obs.log(:log_collection_number_updated, name: format_name, touch: true)
    end
  end

  def log_destroy
    observations.each do |obs|
      obs.log(:log_collection_number_removed, name: format_name, touch: true)
    end
  end

  def destroy_without_callbacks
    delete_manager = arel_delete_collection_numbers
    self.class.connection.execute(delete_manager.to_sql)
  end

  private

  # DELETE FROM collection_numbers WHERE id = #{id}
  def arel_delete_collection_numbers
    cn = Arel::Table.new(:collection_numbers)
    Arel::DeleteManager.new.from(cn).where(cn[:id].eq(id))
  end

  public

  # Mirror changes to collection number in herbarium records.  Do this
  # low-level to avoid redundant rss logs and other callbacks.
  def change_corresponding_herbarium_records(old_format_name)
    update_manager = arel_update_corresponding_herbarium_records(
      old_format_name
    )
    # puts(update_manager.to_sql)
    Observation.connection.execute(update_manager.to_sql)
  end

  private

  # UPDATE collection_numbers_observations cno,
  #   herbarium_records_observations hro,
  #   herbarium_records hr
  # SET hr.accession_number = #{new_format_name}
  #   WHERE cno.collection_number_id = #{id}
  #   AND cno.observation_id = hro.observation_id
  #   AND hro.herbarium_record_id = hr.id
  #   AND hr.accession_number = #{old_format_name}
  def arel_update_corresponding_herbarium_records(old_format_name)
    new_format_name = Observation.connection.quote_string(format_name)
    old_format_name = Observation.connection.quote_string(old_format_name)
    join_sources = arel_join_source_corresponding_tables(old_format_name)

    # puts(join_sources.to_sql)
    Arel::UpdateManager.new.
      table(join_sources).
      set([[HerbariumRecord[:accession_number], new_format_name]])
  end

  def arel_join_source_corresponding_tables(old_format_name)
    cno = Arel::Table.new(:collection_numbers_observations)
    hro = Arel::Table.new(:herbarium_records_observations)
    hr = Arel::Table.new(:herbarium_records)

    on_hro = hr.create_on(hr[:accession_number].eq(old_format_name).
                          and(hro[:herbarium_record_id].eq(hr[:id])))
    join_hr_hro = Arel::Nodes::JoinSource.new(
      hr,
      [hr.create_join(hro, on_hro)]
    )
    on_cno = hr.create_on(cno[:collection_number_id].eq(id).
                          and(cno[:observation_id].eq(hro[:observation_id])))
    Arel::Nodes::JoinSource.new(
      join_hr_hro,
      [join_hr_hro.create_join(cno, on_cno)]
    )
  end
end
