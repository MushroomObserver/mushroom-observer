class Query::Base
  include Query::Modules::ActiveRecord
  include Query::Modules::Coercion
  include Query::Modules::Conditions
  include Query::Modules::HighLevelQueries
  include Query::Modules::Initialization
  include Query::Modules::Joining
  include Query::Modules::LowLevelQueries
  include Query::Modules::NestedQueries
  include Query::Modules::Ordering
  include Query::Modules::SequenceOperators
  include Query::Modules::Serialization
  include Query::Modules::Sql
  include Query::Modules::Titles
  include Query::Modules::Validation

  def flavor
    self.class.to_s.sub(/^.*::/, "")[model.to_s.length..-1].underscore.to_sym
  end

  def parameter_declarations
    {
      join?:   [:string],
      tables?: [:string],
      where?:  [:string],
      group?:  :string,
      order?:  :string,
      by?:     :string,
      title?:  [:string]
    }
  end

  def takes_parameter?(key)
    parameter_declarations.key?(key) ||
      parameter_declarations.key?("#{key}?".to_sym)
  end

  def initialize_flavor
    add_join_from_string(params[:join]) if params[:join]
    self.tables += params[:tables]      if params[:tables]
    self.where  += params[:where]       if params[:where]
    self.group   = params[:group]       if params[:group]
    self.order   = params[:order]       if params[:order]
  end

  def default_order
    raise "Didn't supply default order for #{model} #{flavor} query."
  end

  def ==(other)
    serialize == other.try(&:serialize)
  end
end
