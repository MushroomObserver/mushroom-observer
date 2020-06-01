# frozen_string_literal: true

class Query::HerbariumRecordInHerbarium < Query::HerbariumRecordBase
  def parameter_declarations
    super.merge(
      herbarium: Herbarium
    )
  end

  def initialize_flavor
    herbarium = find_cached_parameter_instance(Herbarium, :herbarium)
    title_args[:herbarium] = herbarium.name
    where << "herbarium_records.herbarium_id = '#{herbarium.id}'"
    super
  end
end
