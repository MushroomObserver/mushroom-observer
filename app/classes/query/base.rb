# frozen_string_literal: true

# base class for Query searches
class Query::Base
  include Query::Modules::ClassMethods
  include Query::Modules::ActiveRecord
  include Query::Modules::RelatedQueries
  include Query::Modules::BoundingBox
  include Query::Modules::Conditions
  include Query::Modules::Associations
  include Query::Modules::Datetime
  include Query::Modules::GoogleSearch
  include Query::Modules::HighLevelQueries
  include Query::Modules::Initialization
  include Query::Modules::Joining
  include Query::Modules::LookupObjects
  include Query::Modules::LowLevelQueries
  include Query::Modules::Ordering
  include Query::Modules::SequenceOperators
  include Query::Modules::Serialization
  include Query::Modules::Sql
  include Query::Modules::Titles
  include Query::Modules::Validation

  def parameter_declarations
    self.class.parameter_declarations
  end

  def self.parameter_declarations
    {
      join: [:string],
      tables: [:string],
      where: [:string],
      group: :string,
      order: :string,
      selects: :string,
      by: :string,
      title: [:string]
    }
  end

  def takes_parameter?(key)
    self.class.takes_parameter?(key)
  end

  def self.takes_parameter?(key)
    parameter_declarations.key?(key)
  end

  def subquery_parameters
    self.class.subquery_parameters
  end

  def self.subquery_parameters
    parameter_declarations.select { |key, _v| key.to_s.include?("_query") }
  end

  def initialize_flavor
    # These strings can never come direct from user, so no need to sanitize.
    # (I believe they are only used by the site stats page. -JPH 20190708)
    self.where += params[:where] if params[:where]
    add_join(params[:join]) if params[:join]
  end

  def default_order
    self.class.default_order ||
      raise("Didn't supply default order for #{model} query.")
  end

  def ==(other)
    serialize == other.try(&:serialize)
  end
end
