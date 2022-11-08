# frozen_string_literal: true

class VisualGroupData
  attr_accessor :query

  def initialize(name, vote_limit)
    self.query = tables[:observation_images]
    add_joins
    add_project
    add_conditions(name, vote_limit)
    query.order(tables[:observations][:vote_cache].desc)
  end

  def sql_query
    query.to_sql
  end

  private

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
               attribute(:observation_images, :image_id),
               Arel::Nodes::OuterJoin)
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

  def add_conditions(name, vote_limit)
    query.where(tables[:names][:text_name].matches("%#{name}%"))
    query.where(tables[:observations][:vote_cache].gteq(vote_limit))
  end
end
