# frozen_string_literal: true

class Query::Users < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [User])
  query_attr(:has_contribution, :boolean)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "login", "reverse_login"
                           User[:login]
                         else
                           User[:name]
                         end
  end

  def self.default_order
    :contribution
  end
end
