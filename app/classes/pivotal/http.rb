# encoding: utf-8
class Pivotal
  require 'fileutils'
  require 'net/http'
  require 'net/https'
  require 'json'
  require 'time'

  class << self
    def get_stories(verbose=false)
      touch_cache("stories.new")
      if !cache_exist?("stories")
        json = get_request("stories?limit=1000")
        stories = process_stories(json, verbose)
      else
        time = cache_date("stories")
        json = get_request("stories?limit=1000&updated_after=#{time.utc.iso8601}")
        stories = process_stories(json, verbose)
        Dir.glob(cache_file("story_*.json")).each do |file|
          if File.mtime(file) < time &&
             file.match(/(\d+).json/)
            stories << get_story(Regexp.last_match[1])
          end
        end
      end
      delete_cache("stories")
      FileUtils.mv(cache_file("stories.new"), cache_file("stories"))
      return stories
    ensure
      delete_cache("stories.new")
    end

    def process_stories(json, verbose)
      stories = []
      JSON.parse(json).each do |obj|
        id   = obj["id"]
        name = obj["name"]
        date = obj["updated_at"]
        if TESTING || name != "test"
          if cache_exist?("story_#{id}.json") &&
             cache_date("story_#{id}.json") > Time.iso8601(date)
            story = get_story(id)
          else
            puts "Reading story ##{id}..." if verbose
            story = Pivotal::Story.new(obj)
            write_cache("story_#{story.id}.json", story.to_json)
          end
          stories << story
        end
      end
      return stories
    end

    def get_story(id, refresh_cache=false)
      if !refresh_cache && cache_exist?("story_#{id}.json")
        json = read_cache("story_#{id}.json")
        story = Pivotal::Story.new(json)
      else
        json = get_request("stories/#{id}")
        story = Pivotal::Story.new(json)
        write_cache("story_#{id}.json", story.to_json)
      end
      return story
    end

    def create_story(name, description, user)
      data = {
        "name" => name,
        "story_type" => "feature",
        "description" => prepare_text(description, user)
      }
      json = post_request("stories", data)
      story = Pivotal::Story.new(json)
      write_cache("story_#{story.id}.json", story.to_json)
      return story
    end

    # Just used by unit tests to clean up temp story created during test.
    def delete_story(story_id)
      delete_request("stories/#{story_id}")
      delete_cache("story_#{story_id}.json")
    end

    def get_comments(story_id)
      json = get_request("stories/#{story_id}/comments")
      return JSON.parse(json).map do |obj|
        Pivotal::Comment.new(obj)
      end
    end

    def post_comment(story_id, user, text)
      data = {"text" => prepare_text(text, user)}
      json = post_request("stories/#{story_id}/comments", data)
      delete_cache("story_#{story_id}.json")
      return Pivotal::Comment.new(json)
    end

    def cast_vote(story_id, user, value)
      story = get_story(story_id, :refresh_cache)
      story.change_vote(user, value)
      new_desc = prepare_text(story.description, story.user, story.votes)
      data = {"description" => new_desc}
      put_request("stories/#{story_id}", data)
      write_cache("story_#{story_id}.json", story.to_json)
      return story
    end

    def prepare_text(text, user=nil, votes=[])
      text = text.sub(/\A\s+/, "").sub(/\s*\Z/, "\n\n")
      if user
        text += "USER: #{user.id} (#{user.name})\n"
      end
      votes.each do |vote|
        text += "VOTE: #{vote.id} #{vote.value}\n"
      end
      return text
    end

  private

    # ----------------------------
    #  HTTP methods.
    # ----------------------------

    def do_request(method, end_path, data=nil)
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
      return @https.request(req).body
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

    # ----------------------------
    #  Cache methods.
    # ----------------------------

    def cache_file(cache_name)
      "#{MO.pivotal_cache}/#{cache_name}"
    end

    def cache_exist?(cache_name)
      file = cache_file(cache_name)
      File.exist?(file)
    end

    def cache_date(cache_name)
      file = cache_file(cache_name)
      File.mtime(file) if File.exist?(file)
    end

    def touch_cache(cache_name)
      create_cache_directory
      file = cache_file(cache_name)
      FileUtils.touch(file)
    end

    def read_cache(cache_name)
      file = cache_file(cache_name)
      File.read(file)
    end

    def write_cache(cache_name, text)
      create_cache_directory
      file = cache_file(cache_name)
      File.open(file, "w:utf-8") {|f| f.write(text.to_s.force_encoding("utf-8"))}
    end

    def delete_cache(cache_name)
      file = cache_file(cache_name)
      File.delete(file) if File.exists?(file)
    end

    def create_cache_directory
      FileUtils.mkpath(MO.pivotal_cache) unless File.directory?(MO.pivotal_cache)
    end
  end
end
