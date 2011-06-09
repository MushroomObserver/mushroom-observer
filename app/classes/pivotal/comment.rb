# encoding: utf-8
class Pivotal
  class Comment
    attr_accessor :id
    attr_accessor :time
    attr_accessor :user
    attr_accessor :text
    attr_accessor :xml
    
    def initialize(xml)
      @xml = xml
    end

    def id;   parse; @id;   end
    def time; parse; @time; end
    def user; parse; @user; end
    def text; parse; @text; end

    # Delay parsing of XML until actually need the comment.
    # In most cases we probably won't ever need it.
    def parse
      if !@id
        @id = 0
        xml.each_element do |elem|
          case elem.name
          when 'id'       ; @id   = elem.text
          when 'noted_at' ; @time = elem.text
          when 'author'   ; @user ||= elem.text
          when 'text'     ; self.text = elem.text
          end
        end
      end
    end

    def text=(str)
      @text = str.split(/\n/).select do |line|
        if line.match(/USER:\s*(\d+)\s+(\S.*\S)/)
          @user = User.find($1) rescue $2.sub(/^\((.*)\)$/, '\\1')
          false
        else
          true
        end
      end.join("\n").sub(/\A\s+/, '').sub(/\s+\Z/, "\n")
    end
  end
end
