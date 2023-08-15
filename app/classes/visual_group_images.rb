# frozen_string_literal: true

class VisualGroupImages
  # VOTE_LIMIT = 1.5

  attr_accessor :query

  def initialize(visual_group, name, included, count = nil)
    self.query = tables[:observation_images]
    add_joins(included)
    add_project
    add_conditions(visual_group, name, included)
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

  def add_joins(included)
    join_type = if included.nil?
                  Arel::Nodes::OuterJoin
                else
                  Arel::Nodes::InnerJoin
                end
    join_table(:visual_group_images, :image_id,
               attribute(:observation_images, :image_id),
               join_type)
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

  def add_project
    query.project(attribute(:observation_images, :image_id),
                  attribute(:visual_group_images, :included),
                  attribute(:observations, :vote_cache))
  end

  def add_conditions(visual_group, name, included)
    query.where(attribute(:names, :text_name).eq(name))
    # query.where(attribute(:observations, :vote_cache).gteq(VOTE_LIMIT))
    query.where(attribute(:visual_group_images, :visual_group_id).eq(visual_group.id))
    query.where(attribute(:visual_group_images, :included).eq(included))
  end
end
