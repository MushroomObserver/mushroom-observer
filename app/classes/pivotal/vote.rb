class Pivotal
  class Vote
    attr_accessor :id
    attr_accessor :value

    def initialize(id, value)
      @id    = id.to_i
      @value = value.to_i
    end
  end
end
