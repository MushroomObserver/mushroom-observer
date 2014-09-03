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
    attr_accessor :comments
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
      'publications'    => 2,
      'search'          => 2,
      'taxonomy'        => 2,
      'upgrade'         => 2,
      'vagrant'         => 2,
      'voting'          => 2,
      'other'           => 2,
      'admin'           => 1,
      'code'            => 1,
      'server'          => 1,
      'open'            => 0,
    }

    def initialize(json)
      data = json.is_a?(String) ? JSON.parse(json) : json
      @id    = data["id"]
      @type  = data["story_type"]
      @time  = data["estimate"]
      @state = data["current_state"]
      @name  = data["name"]
      @user  = nil
      @votes = []
      @description = parse_description(data["description"])
      @labels = data["labels"] == [] ? ["other"] :
                data["labels"].map {|l| l["name"]}
      @comments = !data["comments"] ? [] :
                  data["comments"].map {|c| Pivotal::Comment.new(c)}
    end

    def to_json
      JSON.dump(
        "id" => @id,
        "story_type" => @type,
        "estimate" => @time,
        "current_state" => @state,
        "name" => @name,
        "description" => Pivotal.prepare_text(@description, @user, @votes),
        "labels" => @labels.map do |l|
          { "name" => l }
        end,
        "comments" => @comments.map do |c|
          { "id" => c.id,
          "created_at" => c.time,
          "text" => Pivotal.prepare_text(c.text, c.user) }
        end
      )
    end

    def parse_description(str)
      str.to_s.split(/\n/).select do |line|
        if line.match(/USER:\s*(\d+)\s+(\S.*\S)/)
          id   = Regexp.last_match[1]
          name = Regexp.last_match[2]
          @user = Pivotal::User.new(id, name)
          false
        elsif line.match(/VOTE:\s*(\d+)\s+(\S+)/)
          id    = Regexp.last_match[1]
          value = Regexp.last_match[2]
          @votes << Pivotal::Vote.new(id, value)
          false
        else
          true
        end
      end.join("\n").sub(/\A\s+/, "").sub(/\s+\Z/, "\n")
    end

    def active?
      ACTIVE_STATES[state] || false
    end

    def activity
      @activity ||= begin
        result = "none"
        if @comments.any?
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
      @view_order ||= -((max * 1000 + score) * 100) + comments.length
    end

    def score
      @score ||= votes.inject(0) do |sum, vote|
        sum + vote.value
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
          return vote.value if vote.id == user_id
        end
      end
      return 0
    end

    def change_vote(user, value)
      found = false
      votes.each do |vote|
        if vote.id == user.id
          vote.value = value
          found = true
        end
      end
      votes << Pivotal::Vote.new(user.id, value) if !found
    end
  end
end
