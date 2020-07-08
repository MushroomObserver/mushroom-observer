# frozen_string_literal: true

class Pivotal
  class User
    attr_accessor :id
    attr_accessor :name

    def initialize(id, name)
      @id   = id.to_i
      @name = name.to_s.sub(/^\((.*)\)$/, '\1')
    end
  end
end
