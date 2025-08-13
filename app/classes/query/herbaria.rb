# frozen_string_literal: true

class Query::Herbaria < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Herbarium])
  query_attr(:code_has, :string)
  query_attr(:name_has, :string)
  query_attr(:description_has, :string)
  query_attr(:mailing_address_has, :string)
  query_attr(:pattern, :string)
  query_attr(:nonpersonal, :boolean)

  def alphabetical_by
    @alphabetical_by ||= Herbarium[:name]
  end

  def self.default_order
    :records
  end
end
