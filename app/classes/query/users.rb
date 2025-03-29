# frozen_string_literal: true

class Query::Users < Query::BaseAR
  def model
    @model ||= User
  end

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by]
                 when "login", "reverse_login"
                   User[:login]
                 else
                   User[:name]
                 end
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [User],
      has_contribution: :boolean,
      pattern: :string
    )
  end

  def self.default_order
    :name
  end
end
