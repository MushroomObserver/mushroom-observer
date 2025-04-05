# frozen_string_literal: true

class Query::Users < Query::BaseNew
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [User],
      has_contribution: :boolean,
      pattern: :string
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= User
  end

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "login", "reverse_login"
                           User[:login]
                         else
                           User[:name]
                         end
  end

  def self.default_order
    :name
  end
end
