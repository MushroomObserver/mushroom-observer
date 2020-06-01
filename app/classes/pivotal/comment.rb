# frozen_string_literal: true

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

    def id
      parse
      @id
    end

    def time
      parse
      @time
    end

    def user
      parse
      @user
    end

    def text
      parse
      @text
    end

    # Delay parsing of JSON until actually need the comment.
    # In most cases we probably won't ever need it.
    def parse
      unless @id
        data = @json.is_a?(String) ? JSON.parse(@json) : @json
        @id = data["id"]
        @time = data["created_at"]
        @text = parse_text(data["text"])
      end
    end

    def parse_text(str)
      str.to_s.split(/\n/).select do |line|
        if line =~ /USER:\s*(\d+)\s+(\S.*\S)/
          id   = Regexp.last_match[1]
          name = Regexp.last_match[2]
          @user = Pivotal::User.new(id, name)
          false
        else
          true
        end
      end.join("\n").sub(/\A\s+/, "").sub(/\s+\Z/, "\n")
    end
  end
end
