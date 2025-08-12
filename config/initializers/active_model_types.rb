# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActiveModel::Type.register(:query_param, QueryParamType)
  ActiveModel::Type.register(:search_param, SearchParamType)
end
