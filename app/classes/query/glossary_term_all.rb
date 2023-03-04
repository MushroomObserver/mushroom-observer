# frozen_string_literal: true

module Query
  class GlossaryTermAll < Query::GlossaryTermBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
