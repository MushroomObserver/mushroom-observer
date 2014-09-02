# encoding: utf-8
class Pivotal
  class Story
    attr_accessor :id
    attr_accessor :type
    attr_accessor :time
    attr_accessor :state
    attr_accessor :user
    attr_accessor :name
    attr_accessor :description
    attr_accessor :labels
    attr_accessor :votes

    ACTIVE_STATES = {
      'unscheduled' => true,
      'unstarted'   => true,
      'started'     => true,
      'finished'    => false,
      'accepted'    => false,
    }

    LABEL_VALUE = {
      'critical'        => 4,
      'bottleneck'      => 3,
      'api'             => 2,
      'design'          => 2,
      'documentation'   => 2,
      'email'           => 2,
      'eol'             => 2,
      'github'          => 2,
      'glossary'        => 2,
      'herbarium'       => 2,
      'i18n'            => 2,
      'images'          => 2,
      'interface'       => 2,
      'lists'           => 2,
      'locations'       => 2,
      'names'           => 2,
      'observations'    => 2,
      'pivotal_tracker' => 2,
      'projects'        => 2,
      'search'          => 2,
      'taxonomy'        => 2,
      'vagrant'         => 2,
      'voting'          => 2,
      'other'           => 2,
      'admin'           => 1,
      'code'            => 1,
      'server'          => 1,
      'open'            => 0,
    }

    def initialize(json)
      @id          = nil
      @type        = nil
      @time        = nil
      @state       = nil
      @user        = nil
      @name        = ""
      @description = ""
      @labels      = []
      @votes       = []
      @comments    = nil

      data = json.is_a?(String) ? JSON.parse(json) : json
      @id     = data["id"]
      @type   = data["story_type"]
      @time   = data["estimate"]
      @state  = data["current_state"]
      @name   = data["name"]
      @labels = data["labels"].map {|l| l["name"]}
      @labels = ["other"] if @labels.empty?
      self.description = data["description"]
    end

    def description=(str)
      @description = str.to_s.split(/\n/).select do |line|
        if line.match(/USER:\s*(\d+)\s+(\S.*\S)/)
          @user = User.find($1) rescue $2.sub(/^\((.*)\)$/, '\\1')
          false
        elsif line.match(/VOTE:\s*(\d+)\s+(\S+)/)
          @votes << Pivotal::Vote.new($1, $2)
          false
        else
          true
        end
      end.join("\n").sub(/\A\s+/, "").sub(/\s+\Z/, "\n")
    end

    def comments
      @comments ||= Pivotal.get_comments(@id)
    end

    def active?
      ACTIVE_STATES[state] || false
    end

    def activity
      @activity ||= begin
        result = "none"
        if @comments
          comment = @comments.last
          time = Time.parse(comment.time)
          if time > 1.day.ago
            result = "day"
          elsif time > 1.week.ago
            result = "week"
          elsif time > 1.month.ago
            result = "month"
          end
        end
        result
      end
    end

    def story_order
      max = labels.map {|l| LABEL_VALUE[l].to_i}.max.to_i
      @view_order ||= -((max * 1000 + score) * 100) # + comments.length)
      # Can't include comments any more because they aren't returned
      # with the story.  We would have to request the comments for each
      # and every one of our hundreds of stories, which takes minutes.
    end

    def score
      @score ||= votes.inject(0) do |sum, vote|
        sum + vote.data
      end
    end

    def self.label_value(label)
      LABEL_VALUE[label].to_i
    end
    def label_value(label)
      LABEL_VALUE[label].to_i
    end

    def sorted_labels
      labels.select do |label|
        !label.match(/^(requires .*|votes:.*|jason)$/)
      end.sort_by do |label|
        (9 - LABEL_VALUE[label].to_i).to_s + label
      end
    end

    def user_vote(user)
      if user
        user_id = user.id
        for vote in votes
          return vote.data if vote.id == user_id
        end
      end
      return 0
    end
  end
end
