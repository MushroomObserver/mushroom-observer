# frozen_string_literal: true

module Query
  class FieldSlipAll < Query::FieldSlipBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
