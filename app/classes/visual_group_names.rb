# frozen_string_literal: true

class VisualGroupNames
  attr_accessor :query

  def initialize(visual_group_id, count = nil)
    self.query = tables[:observation_images]
    add_joins
    add_project
    add_conditions(visual_group_id)
    add_order_and_limit(count)
  end

  def sql_query
    query.to_sql
  end

  private

  def add_order_and_limit(count)
    query.order(attribute(:names, :text_name).asc)
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

  def add_joins
    join_table(:visual_group_images, :image_id,
               attribute(:observation_images, :image_id))
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
    query.project(attribute(:names, :text_name)).distinct
  end

  def add_conditions(visual_group_id)
    query.where(tables[:visual_group_images][:included].eq(true))
    query.where(tables[:visual_group_images][:visual_group_id].
                eq(visual_group_id))
  end
end
