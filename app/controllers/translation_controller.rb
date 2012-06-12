# encoding: utf-8

class TranslationController < ApplicationController

  # ----------------------------
  #  :section: Edit Actions
  # ----------------------------

  def edit_translations # :norobots:
    @lang = get_language_and_authorize_user
    @ajax = false
    @page = params[:page]
    @tag = params[:commit] == :CANCEL.l ? nil : params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    @show_tags = tags_to_show(@page, @strings)
    get_record_maps(@lang, @show_tags.keys + @edit_tags)
    update_translations(@edit_tags) if params[:commit] == :SAVE.l
    @form = build_form(@lang, @show_tags)
  rescue => e
    raise error if TESTING and @lang
    flash_error(*error_message(e))
    redirect_back_or_default('/')
  end

  def edit_translations_ajax_get # :norobots:
    @lang = get_language_and_authorize_user
    @ajax = true
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    get_record_maps(@lang, @edit_tags)
    render(:partial => 'form')
  rescue => e
    msg = error_message(e).join("\n")
    render(:text => msg, :status => 500)
  end

  def edit_translations_ajax_post # :norobots:
    @lang = get_language_and_authorize_user
    @ajax = true
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    get_record_maps(@lang, @edit_tags)
    update_translations(@edit_tags)
    render(:partial => 'ajax_post')
  rescue => e
    @error = error_message(e).join("\n")
    render(:partial => 'ajax_error')
  end

  # -------------------------------
  #  :section: Supporting Methods
  # -------------------------------

  def error_message(error)
    msg = [error.to_s]
    if DEVELOPMENT and @lang
      for line in error.backtrace
        break if line.match(/action_controller.*perform_action/)
        msg << line
      end
    end
    return msg
  end

  def get_language_and_authorize_user
    locale = params[:locale] || Locale.code
    lang = Language.find_by_locale(locale)
    if !lang
      raise(:edit_translations_bad_locale.t(:locale => locale))
    elsif !@user
      raise(:edit_translations_login_required.t)
    elsif lang.official and !is_reviewer?
      raise(:edit_translations_reviewer_required.t)
    end
    return lang
  end

  def get_record_maps(lang, tags)
    @translated_records = build_record_map(lang, tags)
    if lang.official
      @official_records = @translated_records
    else
      @official_records = build_record_map(Language.official, tags)
    end
  end

  def build_record_map(lang, tags)
    result = {}
    # (If we just get the strings for the given tags, then it doesn't update
    # lang.translation_strings's cache correctly, and we have it end up loading
    # all the strings later, anyway!)
    for str in lang.translation_strings
      result[str.tag] = str
    end
    return result
  end

  def update_translations(tags)
    any_changes = false
    for tag in tags
      old_val = @strings[tag].to_s
      new_val = params["tag_#{tag}"].to_s rescue ''
      old_val = @lang.clean_string(old_val)
      new_val = @lang.clean_string(new_val)
      str = @translated_records[tag]
      if not str
        create_translation(tag, new_val)
        any_changes = true
      elsif old_val != new_val
        change_translation(str, new_val)
        any_changes = true
      end
      @strings[tag] = new_val
    end
    if any_changes
      @lang.update_localization_file
      @lang.update_export_file
    else
      flash_warning(:edit_translations_no_changes.t) if !@ajax
    end
  end

  def create_translation(tag, val)
    str = @lang.translation_strings.create(
      :tag => tag,
      :text => val
    )
    @translated_records[tag] = str
    str.update_localization
    flash_notice(:edit_translations_created.t(:tag => tag, :str => val)) if !@ajax
  end

  def change_translation(str, val)
    str.update_attributes!(
      :text => val
    )
    str.update_localization
    flash_notice(:edit_translations_changed.t(:tag => str.tag, :str => val)) if !@ajax
  end

  def preview_string(str, limit=250)
    str = @lang.clean_string(str)
    str = str.gsub(/\n/, ' / ')
    if str.length > limit
      str = str[0..limit] + '...'
    end
    return str
  end
  helper_method :preview_string

  def tags_to_edit(tag, strings)
    tag_list = []
    unless tag.blank?
      for t in [tag, tag+'s', tag.upcase, (tag+'s').upcase]
        tag_list << t if strings.has_key?(t)
      end
    end
    return tag_list
  end

  def tags_used_on_page(page)
    tag_list = nil
    unless page.blank?
      tag_list = Language.load_tags(page)
      unless tag_list
        flash_error(:edit_translations_page_expired.t)
      end
    end
    return tag_list
  end

  def tags_to_show(page, strings)
    hash = {}
    for tag in tags_used_on_page(page) || strings.keys
      primary = primary_tag(tag, strings)
      hash[primary] = true
    end
    return hash
  end

  def primary_tag(tag3, strings)
    tag2 = tag3 + 's'
    tag1 = tag3.sub(/s$/i,'')
    for tag in [
      tag1.downcase,
      tag2.downcase,
      tag3.downcase,
      tag1.upcase,
      tag2.upcase,
      tag3.upcase,
      tag1,
      tag2
    ]
      return tag if strings[tag]
    end
    return tag3
  end

  # ----------------------------
  #  :section: Edit Form
  # ----------------------------

  def build_form(lang, tags, fh=nil)
    @form = []
    @tags = tags
    fh ||= File.open(lang.export_file, 'r')
    reset_everything
    fh.each_line do |line|
      line.force_encoding('utf-8')
      process_template_line(line)
    end
    process_blank_line
    fh.close if fh.respond_to?(:close)
    return @form
  end

  def reset_everything
    @major_head = []
    @minor_head = []
    @comments = []
    @section = []
    @on_pages = false
    @do_section = false
    @in_tag = false
    @expecting_minor_head = false
  end

  def process_template_line(line)
    if line.match(/^['"]?(\w+)['"]?:\s*/)
      tag, str = $1, $'
      process_tag_line(tag)
      @in_tag = true if str.match(/^>/)
    elsif @in_tag
      @in_tag = false unless line.match(/\S/)
    elsif line.blank?
      process_blank_line
    elsif line.match(/^\s*#\s*(.*)/)
      process_comment($1)
    end
  end

  def process_tag_line(tag)
    @expecting_minor_head = false
    if @tags[tag]
      if @on_pages
        @do_section = true
      else
        add_headers
        @form << TranslationFormComment.new(*@comments) if @comments.any?
        @form << TranslationFormTagField.new(tag)
      end
    end
    if @on_pages
      @section << TranslationFormComment.new(*@comments) if @comments.any?
      @section << TranslationFormTagField.new(tag)
    end
    @comments.clear
  end

  def process_blank_line
    if @on_pages
      if @do_section
        add_headers
        @form += @section
      end
      @section.clear
      @do_section = false
    end
    @minor_head = []
    @expecting_minor_head = true
  end

  def process_comment(str)
    if str.match(/#############/)
      reset_everything
    elsif str.match(/^[A-Z][^a-z]*(--|$)/)
      @major_head << str
      @on_pages = !!str.match(/PAGES/)
    elsif @expecting_minor_head
      @minor_head << str
    else
      @comments << str
    end
  end

  def add_headers
    @form << TranslationFormMajorHeader.new(*@major_head) if @major_head.any?
    @form << TranslationFormMinorHeader.new(*@minor_head) if @minor_head.any?
    @major_head.clear
    @minor_head.clear
  end

  class TranslationFormString
    attr_accessor :string
    def initialize(*strs)
      self.string = strs.join("\n")
    end
    alias to_s string
  end

  class TranslationFormMajorHeader < TranslationFormString
  end

  class TranslationFormMinorHeader < TranslationFormString
  end

  class TranslationFormComment < TranslationFormString
  end

  class TranslationFormTagField < TranslationFormString
    alias tag string
  end
end
