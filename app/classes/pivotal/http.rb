# encoding: utf-8
class Pivotal
  require 'net/http'
  require 'net/https'
  require 'json'

  class << self
    def get_stories
      json = get_cache_or_request("all_stories",
        "/projects/#{MO.pivotal_project}/stories?limit=1000")
      stories = []
      JSON.parse(json).each do |obj|
        story = Pivotal::Story.new(obj)
        if TESTING or !story.name.match(/^test|temp$/)
          stories << story
        end
      end
      return stories
    end

    def get_story(id)
      json = get_cache_or_request("story_#{id}",
        "/projects/#{MO.pivotal_project}/stories/#{id}")
      return Pivotal::Story.new(json)
    end

    def create_story(name, description, user)
      data = {
        "name" => name,
        "story_type" => "feature",
        "description" => prepare_text(description, user)
      }
      json = post_request("/projects/#{MO.pivotal_project}/stories", data)
      write_cache("story_#{story.id}", json)
      delete_cache("all_stories")
      return Pivotal::Story.new(json)
    end

    # Just used by unit tests to clean up temp story created during test.
    def delete_story(id)
      delete_request("/projects/#{MO.pivotal_project}/stories/#{id}")
    end

    def get_comments(id)
      json = get_cache_or_request("comments_#{id}",
        "/projects/#{MO.pivotal_project}/stories/#{id}/comments")
      return JSON.parse(json).map do |obj|
        Pivotal::Comment.new(obj)
      end
    end

    def post_comment(id, user, text)
      data = {"text" => prepare_text(text, user)}
      json = post_request("/projects/#{MO.pivotal_project}/stories/#{id}/comments", data)
      delete_cache("comments_#{id}")
      return Pivotal::Comment.new(json)
    end

    def cast_vote(id, user, value)
      json = get_cache_or_request("story_#{id}",
        "/projects/#{MO.pivotal_project}/stories/#{id}")
      data = JSON.parse(json)
      desc = data["description"] || ""
      desc = desc.split(/\n/).reject do |line|
        line.match(/VOTE:\s*(\d+)\s*(\d+)/) and $1.to_i == user.id
      end.join("\n")
      desc += "\nVOTE: #{user.id} #{value}\n"
      data = {"description" => desc}
      json = put_request("/projects/#{MO.pivotal_project}/stories/#{id}", data)
      write_cache("story_#{id}", json)
      delete_cache("all_stories")
      return Pivotal::Story.new(json)
    end

  private

    def do_request(method, path, data=nil)
      # Use same HTTP connection for duration of this MO request.
      @https ||= Net::HTTP.new(MO.pivotal_url, 443)
      @https.use_ssl = true
      headers = { "X-TrackerToken" => MO.pivotal_token }
      case method
      when "GET"
        req = Net::HTTP::Get.new(MO.pivotal_path + path, headers)
      when "PUT"
        req = Net::HTTP::Put.new(MO.pivotal_path + path, headers)
        req.content_length = data.length
        req.content_type = "application/json"
        req.body = data.to_s
      when "POST"
        req = Net::HTTP::Post.new(MO.pivotal_path + path, headers)
        req.content_length = data.length
        req.content_type = "application/json"
        req.body = data.to_s
      when "DELETE"
        req = Net::HTTP::Delete.new(MO.pivotal_path + path, headers)
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

    def delete_cache(filename)
      file = "#{MO.pivotal_cache}/#{filename}.json"
      File.delete(file) if File.exists?(file)
    end

    def write_cache(filename, text)
      FileUtils.mkpath(MO.pivotal_cache) unless File.directory?(MO.pivotal_cache)
      file = "#{MO.pivotal_cache}/#{filename}.json"
      File.open(file, "w:utf-8") {|f| f.write(text.to_s.force_encoding("utf-8"))}
    end

    def get_cache_or_request(filename, path)
      file = "#{MO.pivotal_cache}/#{filename}.json"
      if File.exists?(file) and
         File.mtime(file) > 1.hour.ago
        result = File.read(file)
      else
        result = get_request(path)
        write_cache(filename, result)
      end
      return result
    end

    def prepare_text(text, user)
      text = text.sub(/\A\s+/, "").sub(/\s*\Z/, "\n\n")
      text += "USER: #{user.id} (#{user.login})\n"
    end
  end
end
