# frozen_string_literal: true

class API2
  # Error while executing query.
  class QueryError < Error
    def initialize(error)
      super()
      args.merge!(error: error.to_s)
    end
  end
end
