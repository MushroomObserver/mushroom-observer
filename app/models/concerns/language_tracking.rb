# frozen_string_literal: true

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
#    <%= if Language.tracking_usage?
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
  # `tags_used` tracks which tags got used on the CURRENT page/request
  # - `before_action { Language.track_usage }` primes it, later code
  # in that same request reads it back via `note_usage_of_tag`/
  # `tags_used`/`save_tags`. That's request-scoped state, not global -
  # `Thread.current[...]` isolates it across concurrent requests the
  # same way Textile's name-lookup cache does (see app/classes/
  # textile.rb). `last_clean` (below) is different: a genuinely
  # global, cross-request throttle on the temp-file cleanup sweep, so
  # it's a plain class-level instance variable on Language instead
  # (see periodically_clean_up).
  TAGS_USED_KEY = :mo_language_tracking_tags_used
  private_constant(:TAGS_USED_KEY)

  # Turn on tracking.  If optional page is passed in, then it will seed the
  # list of tags with those from the other page.  Use this if redirecting
  # one or more times: track for page1, redirect and pass tags on to page2,
  # and so on, until done redirecting.
  def track_usage(last_page = nil)
    Thread.current[TAGS_USED_KEY] = {}
    return unless (seed_tags = load_tags(last_page))

    seed_tags.each do |ttag|
      Thread.current[TAGS_USED_KEY][ttag] = true
    end
  end

  def ignore_usage
    Thread.current[TAGS_USED_KEY] = nil
  end

  def tracking_usage?
    !!Thread.current[TAGS_USED_KEY]
  end

  def note_usage_of_tag(ttag)
    return unless Thread.current[TAGS_USED_KEY]

    Thread.current[TAGS_USED_KEY][ttag.to_s] =
      true
  end

  def tags_used
    Thread.current[TAGS_USED_KEY].keys
  end

  def save_tags
    name = String.random(16)
    file = tag_file(name)
    File.open(file, "w:utf-8") do |fh|
      tags_used.each do |ttag|
        fh.puts(ttag)
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
    path = Rails.root.join("tmp/language_tracking")
    FileUtils.mkpath(path) unless File.exist?(path)
    "#{path}/#{name}.txt"
  end

  def periodically_clean_up
    cutoff = 10.minutes.ago
    return unless !@last_clean || @last_clean < cutoff

    @last_clean = Time.zone.now
    glob = tag_file("*")
    Dir.glob(glob).each do |file|
      File.delete(file) if File.mtime(file) < cutoff
    rescue StandardError
      # I've seen this fail because of files presumably being deleted by
      # another process between Dir.glob and File.mtime.
    end
  end
end
