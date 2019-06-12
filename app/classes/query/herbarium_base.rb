class Query::HerbariumBase < Query::Base
  def model
    Herbarium
  end

  def parameter_declarations
    super.merge(
      created_at?:  [:time],
      updated_at?:  [:time],
      code?:        :string,
      name?:        :string,
      description?: :string,
      address?:     :string
    )
  end

  def initialize_flavor
    add_time_condition("herbaria.created_at", params[:created_at])
    add_time_condition("herbaria.updated_at", params[:updated_at])
    add_search_condition("herbaria.code", params[:code])
    add_search_condition("herbaria.name", params[:name])
    add_search_condition("herbaria.description", params[:description])
    add_search_condition("herbaria.mailing_address", params[:address])
    super
  end

  def default_order
    "name"
  end
end
