# frozen_string_literal: true

# /pivotal
class Pivotal
  require "fileutils"
  require "net/http"
  require "net/https"
  require "json"
  require "time"

  class << self
    def get_stories(_verbose = false)
      stories = []

      request_stories("", stories)
      request_stories("&offset=501", stories) if stories.count == 500

      stories
    end

    def request_stories(api_params, stories)
      json = get_request("stories?limit=500&filter=state:unscheduled,"\
                         "started,unstarted&#{story_fields}" + api_params)
      JSON.parse(json).each do |obj|
        if Rails.env.test? || obj["name"] != "test"
          story = Pivotal::Story.new(obj)
          stories << story
        end
      end

      stories
    end

    def get_story(id)
      json = get_request("stories/#{id}?#{story_fields}")
      Pivotal::Story.new(json)
    end

    def create_story(name, description, user)
      data = {
        "name" => name,
        "story_type" => "feature",
        "description" => prepare_text(description, user)
      }
      json = post_request("stories", data)
      Pivotal::Story.new(json)
    end

    # Just used by unit tests to clean up temp story created during test.
    def delete_story(story_id)
      delete_request("stories/#{story_id}")
    end

    def post_comment(story_id, user, text)
      data = { "text" => prepare_text(text, user) }
      json = post_request("stories/#{story_id}/comments", data)
      Pivotal::Comment.new(json)
    end

    def cast_vote(story_id, user, value)
      story = get_story(story_id)
      story.change_vote(user, value)
      new_desc = prepare_text(story.description, story.user, story.votes)
      data = { "description" => new_desc }
      put_request("stories/#{story_id}", data)
      story
    end

    def prepare_text(text, user = nil, votes = [])
      text = text.sub(/\A\s+/, "").sub(/\s*\Z/, "\n\n")
      text += "USER: #{user.id} (#{user.name})\n" if user
      votes.each do |vote|
        text += "VOTE: #{vote.id} #{vote.value}\n"
      end
      text
    end

    def story_fields
      "fields=story_type,estimate,current_state,name,description,updated_at,"\
      "labels(name),comments(created_at,text)"
    end

    def comment_fields
      "fields=created_at,text"
    end

    private

    # ----------------------------
    #  HTTP methods.
    # ----------------------------

    def do_request(method, end_path, data = nil)
      # Use same HTTP connection for duration of this MO request.
      @https ||= Net::HTTP.new(MO.pivotal_url, 443)
      @https.use_ssl = true
      headers = { "X-TrackerToken" => MO.pivotal_token }
      path = "#{MO.pivotal_path}/projects/#{MO.pivotal_project}/#{end_path}"
      case method
      when "GET"
        req = Net::HTTP::Get.new(path, headers)
      when "PUT"
        req = Net::HTTP::Put.new(path, headers)
        req.content_length = data.length
        req.content_type = "application/json"
        req.body = data.to_s
      when "POST"
        req = Net::HTTP::Post.new(path, headers)
        req.content_length = data.length
        req.content_type = "application/json"
        req.body = data.to_s
      when "DELETE"
        req = Net::HTTP::Delete.new(path, headers)
      end
      @https.request(req).body
    end

    def get_request(path)
      do_request("GET", path)
    end

    def put_request(path, data)
      do_request("PUT", path, JSON.dump(data))
    end

    def post_request(path, data)
      do_request("POST", path, JSON.dump(data))
    end

    def delete_request(path)
      do_request("DELETE", path)
    end
  end
end
