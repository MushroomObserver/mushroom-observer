# frozen_string_literal: true

class VisualGroupImages
  # VOTE_LIMIT = 1.5

  attr_accessor :query

  # status should be one of [:included, :excluded, :any, :reviewed]
  def initialize(visual_group, name, status, count = nil)
    self.query = tables[:observation_images]
    add_joins(status)
    add_project(status)
    add_conditions(visual_group, name, status)
    add_order_and_limit(count)
  end

  def vals
    VisualGroup.connection.select_rows(query.to_sql).uniq
  end

  private

  def add_order_and_limit(count)
    query.order(attribute(:observations, :vote_cache).desc)
    query.take(count) unless count.nil?
  end

  def tables
    @tables ||= {
      observation_images: ObservationImage.arel_table,
      visual_group_images: VisualGroupImage.arel_table,
      observations: Observation.arel_table,
      names: Name.arel_table
    }
  end

  def add_joins(status)
    unless status == :any
      join_table(:visual_group_images, :image_id,
                 attribute(:observation_images, :image_id))
    end
    join_table(:observations, :id,
               attribute(:observation_images, :observation_id))
    join_table(:names, :id, attribute(:observations, :name_id))
  end

  def join_table(join_name, join_field, attribute, join_type = nil)
    join_type ||= Arel::Nodes::InnerJoin
    table = tables[join_name]
    join_attribute = table[join_field]
    self.query = query.join(table, join_type).on(join_attribute.eq(attribute))
  end

  def attribute(table_name, field)
    tables[table_name][field]
  end

  def add_project(status)
    included = if [:any, :reviewed].include?(status)
                 "NULL"
               else
                 attribute(:visual_group_images, :included)
               end
    query.project(attribute(:observation_images, :image_id),
                  included,
                  attribute(:observations, :vote_cache))
  end

  def add_conditions(visual_group, name, status)
    query.where(attribute(:names, :text_name).eq(name))
    # query.where(attribute(:observations, :vote_cache).gteq(VOTE_LIMIT))
    return if status == :any

    query.where(attribute(:visual_group_images,
                          :visual_group_id).eq(visual_group.id))
    return if status == :reviewed

    query.where(attribute(:visual_group_images,
                          :included).eq(status == :included))
  end
end
