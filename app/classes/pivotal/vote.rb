# encoding: utf-8
class Pivotal
  class Vote
    attr_accessor :id
    attr_accessor :data

    def initialize(id, data)
      @id   = id.to_i
      @data = data.to_i
    end
  end
end
