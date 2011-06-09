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
      'critical'   => 4,
      'bottleneck' => 3,
      'api'        => 2,
      'design'     => 2,
      'email'      => 2,
      'interface'  => 2,
      'lists'      => 2,
      'locations'  => 2,
      'names'      => 2,
      'projects'   => 2,
      'search'     => 2,
      'taxonomy'   => 2,
      'voting'     => 2,
      'eol'        => 2,
      'i18n'       => 2,
      'other'      => 2,
      'admin'      => 1,
      'code'       => 1,
      'server'     => 1,
      'open'       => 0,
    }

    def initialize(xml)
      @id          = nil
      @type        = nil
      @time        = nil
      @state       = nil
      @user        = nil
      @name        = ''
      @description = ''
      @labels      = []
      @comments    = []
      @votes       = []

      xml.each_element do |elem|
        case elem.name
        when 'id'            ; @id       = elem.text
        when 'story_type'    ; @type     = elem.text
        when 'estimate'      ; @time     = elem.text
        when 'current_state' ; @state    = elem.text
        when 'requested_by'  ; @user   ||= elem.text
        when 'name'          ; @name     = elem.text
        when 'description'   ; self.description = elem.text
        when 'labels'        ; @labels   = elem.text.split(',')
        when 'notes'         ; @comments = elem.elements.map { |e| Pivotal::Comment.new(e) }
        end
      end

      @labels = ['other'] if @labels.empty?
    end

    def description=(str)
      @description = str.split(/\n/).select do |line|
        if line.match(/USER:\s*(\d+)\s+(\S.*\S)/)
          @user = User.find($1) rescue $2.sub(/^\((.*)\)$/, '\\1')
          false
        elsif line.match(/VOTE:\s*(\d+)\s+(\S+)/)
          @votes << Pivotal::Vote.new($1, $2)
          false
        else
          true
        end
      end.join("\n").sub(/\A\s+/, '').sub(/\s+\Z/, "\n")
    end

    def active?
      ACTIVE_STATES[state] || false
    end

    def activity
      @activity ||= begin
        result = 'none'
        if comment = comments.last
          time = Time.parse(comment.time)
          if time > 1.day.ago
            result = 'day'
          elsif time > 1.week.ago
            result = 'week'
          elsif time > 1.month.ago
            result = 'month'
          end
        end
        result
      end
    end

    def story_order
      max = labels.map {|l| LABEL_VALUE[l].to_i}.max.to_i
      @view_order ||= -((max * 1000 + score) * 100 + comments.length)
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
