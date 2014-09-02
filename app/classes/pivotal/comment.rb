# encoding: utf-8
class Pivotal
  class Comment
    attr_accessor :id
    attr_accessor :time
    attr_accessor :user
    attr_accessor :text
    attr_accessor :json
    
    def initialize(json)
      @json = json
    end

    def id;   parse; @id;   end
    def time; parse; @time; end
    def user; parse; @user; end
    def text; parse; @text; end

    # Delay parsing of JSON until actually need the comment.
    # In most cases we probably won't ever need it.
    def parse
      if !@id
        data = @json.is_a?(String) ? JSON.parse(@json) : @json
        @id = data["id"]
        @time = data["created_at"]
        self.text = data["text"]
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
