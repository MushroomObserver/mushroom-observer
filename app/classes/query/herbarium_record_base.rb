module Query
  # Code common to all herbarium_record searches.
  class HerbariumRecordBase < Query::Base
    def model
      HerbariumRecord
    end

    # def initialize_flavor
    #   super
    # end

    def default_order
      "herbarium_label"
    end
  end
end
