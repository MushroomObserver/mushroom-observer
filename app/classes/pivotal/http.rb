# encoding: utf-8
class Pivotal
  require 'net/http'
  require 'net/https'
  require 'rexml/document'

  class << self
    def get_stories
      xml = get_cache_or_request('all_stories.xml',
        '/projects/' + PIVOTAL_PROJECT + '/stories')
      doc = REXML::Document.new(xml)
      stories = []
      doc.root.elements.each('story') do |elem|
        story = Pivotal::Story.new(elem)
        if TESTING or !story.name.match(/^test|temp$/)
          write_cache('story_' + story.id + '.xml', elem)
          stories << story
        end
      end
      return stories
    end

    def get_story(id)
      xml = get_cache_or_request('story_' + id + '.xml',
        '/projects/' + PIVOTAL_PROJECT + '/stories/' + id)
      doc = REXML::Document.new(xml)
      return Pivotal::Story.new(doc.root)
    end

    def create_story(name, description, user)
      data = REXML::Element.new("story")
      data.add_element("story_type").text = "feature"
      data.add_element("name").text = name
      data.add_element("description").text = prepare_text(description, user)
      xml = post_request('/projects/' + PIVOTAL_PROJECT + '/stories', data)
      doc = REXML::Document.new(xml)
      story = Pivotal::Story.new(doc.root)
      write_cache('story_' + story.id + '.xml', xml)
      delete_cache('all_stories.xml')
      return story
    end

    # Just used by unit tests to clean up temp story created during test.
    def delete_story(id)
      xml = delete_request('/projects/' + PIVOTAL_PROJECT + '/stories/' + id)
    end

    def post_comment(id, user, text)
      data = REXML::Element.new("note")
      data.add_element("text").text = prepare_text(text, user)
      xml = post_request('/projects/' + PIVOTAL_PROJECT + '/stories/' + id + '/notes', data)
      doc = REXML::Document.new(xml)
      comment = Pivotal::Comment.new(doc.root)
      delete_cache('story_' + id + '.xml')
      delete_cache('all_stories.xml')
      return comment
    end

    def cast_vote(id, user, value)
      xml = get_cache_or_request('story_' + id + '.xml',
        '/projects/' + PIVOTAL_PROJECT + '/stories/' + id)
      doc = REXML::Document.new(xml)
      desc = doc.root.elements['description'].first.value.to_s
      desc = desc.split(/\n/).reject do |line|
        line.match(/VOTE:\s*(\d+)\s*(\d+)/) and $1.to_i == user.id
      end.join("\n")
      desc += "\nVOTE: #{user.id} #{value}\n"
      data = REXML::Element.new("story")
      data.add_element("description").text = desc
      xml = put_request('/projects/' + PIVOTAL_PROJECT + '/stories/' + id, data)
      doc = REXML::Document.new(xml)
      story = Pivotal::Story.new(doc.root)
      write_cache('story_' + id + '.xml', xml)
      delete_cache('all_stories.xml')
      return story
    end

  private

    def get_token
      https = Net::HTTP.new(PIVOTAL_URL, 443)
      req = Net::HTTP::Get.new(PIVOTAL_PATH + '/tokens/active')
      req.basic_auth(PIVOTAL_USERNAME, PIVOTAL_PASSWORD)
      https.use_ssl = true
      res = https.request(req)
      doc = REXML::Document.new(res.body)
      return doc.root.elements['guid'].first.value
    end

    def do_request(method, path, data=nil)
      # Use same access token for entire life of this server instance.
      @@token ||= get_token
      return nil unless @@token
      # Use same HTTP connection for duration of this MO request.
      @http ||= Net::HTTP.new(PIVOTAL_URL, 80)
      headers = { 'X-TrackerToken' => @@token }
      case method
      when :get
        req = Net::HTTP::Get.new(PIVOTAL_PATH + path, headers)
      when :put
        req = Net::HTTP::Put.new(PIVOTAL_PATH + path, headers)
        req.content_length = data.length
        req.content_type = "application/xml"
        req.body = data.to_s
      when :post
        req = Net::HTTP::Post.new(PIVOTAL_PATH + path, headers)
        req.content_length = data.length
        req.content_type = "application/xml"
        req.body = data.to_s
      when :delete
        req = Net::HTTP::Delete.new(PIVOTAL_PATH + path, headers)
      end
      return @http.request(req).body
    end

    def get_request(path)
      do_request(:get, path)
    end

    def put_request(path, data)
      do_request(:put, path, data)
    end

    def post_request(path, data)
      do_request(:post, path, data)
    end

    def delete_request(path)
      do_request(:delete, path)
    end

    def delete_cache(filename)
      file = PIVOTAL_CACHE + '/' + filename
      File.delete(file) if File.exists?(file)
    end

    def write_cache(filename, text)
      file = PIVOTAL_CACHE + '/' + filename
      Dir.mkdir(PIVOTAL_CACHE) if !File.exists?(PIVOTAL_CACHE)
      File.open(file, 'w') {|f| f.write(text)}
    end

    def get_cache_or_request(filename, path)
      file = PIVOTAL_CACHE + '/' + filename
      if File.exists?(file) and
         File.mtime(file) > 1.hour.ago
        result = File.new(file)
      else
        result = get_request(path)
        write_cache(filename, result)
      end
      return result
    end

    def prepare_text(text, user)
      text = text.sub(/\A\s+/, '').sub(/\s*\Z/, "\n\n")
      text += "USER: #{user.id} (#{user.login})\n"
    end
  end
end
