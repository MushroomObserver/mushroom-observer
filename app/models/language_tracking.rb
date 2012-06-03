# encoding: utf-8
#
#  = Tracking Usage of Translations
#
#  Simple global mechanism for tracking which localization strings get used on
#  a given page.  You would enable it in a +before_filter+ in your controller,
#  then Symbol#localize will have it make note of each tag that gets used
#  throughout the process of rendering that page.  You can save this list of
#  tags to a temporary file, and load it again later for use in a form, for
#  example.  It will periodically clean up old temp files.
#
#    before_filter { Language.track_usage }
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
  @@tags_used = nil
  @@last_clean = nil

  def track_usage
    @@tags_used = {}
  end

  def ignore_usage
    @@tags_used = nil
  end

  def tracking_usage
    !!@@tags_used
  end

  def note_usage_of_tag(tag)
    @@tags_used[tag] = true if @@tags_used
  end

  def tags_used
    @@tags_used.keys
  end

  def save_tags
    name = String.random(16)
    file = tag_file(name)
    File.open(file, 'w') do |fh|
      for tag in tags_used
        fh.puts(tag)
      end
    end
    periodically_clean_up
    return name
  end

  def load_tags(name)
    file = tag_file(name)
    tags = []
    File.open(file, 'r') do |fh|
      fh.each_line do |line|
        tags << line.chomp.to_sym
      end
    end
    return tags
  rescue
    return nil
  end

  def tag_file(name)
    path = "#{RAILS_ROOT}/tmp/language_tracking"
    Dir.mkdir(path) unless File.exists?(path)
    return "#{path}/#{name}.txt"
  end

  def periodically_clean_up
    cutoff = 10.minutes.ago
    if !@@last_clean or @@last_clean < cutoff
      @@last_clean = Time.now
      glob = tag_file('*')
      for file in Dir.glob(glob)
        if File.mtime(file) < cutoff
          File.delete(file)
        end
      end
    end
  end
end
