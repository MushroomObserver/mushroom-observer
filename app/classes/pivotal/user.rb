# encoding: utf-8
class Pivotal
  class User
    attr_accessor :id
    attr_accessor :login

    def initialize(id, login)
      @id    = id.to_i
      @login = login.to_s.sub(/^\((.*)\)$/, '\1')
    end
  end
end
