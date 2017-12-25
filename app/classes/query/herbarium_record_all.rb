module Query
  # All herbarium_records.
  class HerbariumRecordAll < Query::HerbariumRecordBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
