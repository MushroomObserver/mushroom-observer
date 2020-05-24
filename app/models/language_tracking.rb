#
#  = Tracking Usage of Translations
#
#  Simple global mechanism for tracking which localization strings get used on
#  a given page.  You would enable it in a +before_action+ in your controller,
#  then Symbol#localize will have it make note of each tag that gets used
#  throughout the process of rendering that page.  You can save this list of
#  tags to a temporary file, and load it again later for use in a form, for
#  example.  It will periodically clean up old temp files.
#
#    before_action { Language.track_usage }
#
#    <%= if Language.tracking_usage
#      handle = Language.save_tags
#      link_to("edit", :action => :edit_translations, :handle => handle)
#    end %>
#
#    def edit_translations
#      handle = params[:handle]
#      if @tags = Language.read_tags(handle)
#        Language.ignore_usage
#        ...
#      else
#        flash_error "That page has expired, sorry!"
#      end
#    end
#
################################################################################

module LanguageTracking
  require "fileutils"

  @@tags_used = nil
  @@last_clean = nil

  # Turn on tracking.  If optional page is passed in, then it will seed the
  # list of tags with those from the other page.  Use this if redirecting
  # one or more times: track for page1, redirect and pass tags on to page2,
  # and so on, until done redirecting.
  def track_usage(last_page = nil)
    @@tags_used = {}
    if seed_tags = load_tags(last_page)
      for tag in seed_tags
        @@tags_used[tag] = true
      end
    end
  end

  def ignore_usage
    @@tags_used = nil
  end

  def tracking_usage
    !!@@tags_used
  end

  def note_usage_of_tag(tag)
    @@tags_used[tag.to_s] = true if @@tags_used
  end

  def tags_used
    @@tags_used.keys
  end

  def save_tags
    name = String.random(16)
    file = tag_file(name)
    File.open(file, "w:utf-8") do |fh|
      for tag in tags_used
        fh.puts(tag)
      end
    end
    periodically_clean_up
    name
  end

  def load_tags(name)
    file = tag_file(name)
    tags = []
    File.open(file, "r:utf-8") do |fh|
      fh.each_line do |line|
        tags << line.chomp
      end
    end
    FileUtils.touch(file)
    tags
  rescue StandardError
    nil
  end

  private

  def tag_file(name)
    path = "#{::Rails.root}/tmp/language_tracking"
    FileUtils.mkpath(path) unless File.exist?(path)
    "#{path}/#{name}.txt"
  end

  def periodically_clean_up
    cutoff = 10.minutes.ago
    if !@@last_clean || @@last_clean < cutoff
      @@last_clean = Time.zone.now
      glob = tag_file("*")
      for file in Dir.glob(glob)
        begin
          File.delete(file) if File.mtime(file) < cutoff
        rescue StandardError
          # I've seen this fail because of files presumably being deleted by
          # another process between Dir.glob and File.mtime.
        end
      end
    end
  end
end
