# encoding: utf-8

class TranslationController < ApplicationController
  before_filter :authorize

  def authorize
    @lang = Language.find_by_locale(Locale.code)
    if !@lang
      raise "Can't find locale: #{Locale.code}"
    elsif !@user
      flash_error(:edit_translations_login_required.t)
      redirect_back_or_default('/')
    elsif @lang.official and !is_reviewer?
      flash_error(:edit_translations_reviewer_required.t)
      redirect_back_or_default('/')
    end
  end

  def edit_translations # :norobots:
    @ajax = false
    @page = params[:page]
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @translated = @lang.translation_strings_hash
    @edit_tags = tags_to_edit(@tag, @strings)
    update_translations(@edit_tags) if request.method == :post
    tags_used = tags_used_on_page(@page) || @strings.keys
    @show_tags = tags_to_show(tags_used, @strings)
    @form = build_form(@lang, @show_tags)
  end

  def edit_translations_ajax_get # :norobots:
    @ajax = true
    @lang = Language.find_by_locale(Locale.code)
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    render(:partial => 'form')
  rescue => e
    render(:text => e.to_s, :status => 500)
  end

  def edit_translations_ajax_post # :norobots:
    @ajax = true
    @lang = Language.find_by_locale(Locale.code)
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @translated = @lang.translation_strings_hash
    @edit_tags = tags_to_edit(@tag, @strings)
    update_translations(@edit_tags)
    @new_val = @translated[@tag].text
    @new_val = preview_string(@new_val)
    render(:partial => 'ajax_post')
  rescue => e
    @error = e.to_s
    render(:partial => 'ajax_error')
  end

  def update_translations(tags)
    any_changes = false
    for tag in tags
      old_val = @strings[tag].to_s
      new_val = params["tag_#{tag}"].to_s rescue ''
      old_val = @lang.clean_string(old_val)
      new_val = @lang.clean_string(new_val)
      str = @translated[tag]
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
    else
      flash_warning(:edit_translations_no_changes.t) if !@ajax
    end
  end

  def create_translation(tag, val)
    str = @lang.translation_strings.create(
      :tag => tag,
      :text => val,
      :modified => Time.now,
      :user => @user
    )
    str.update_localization
    flash_notice(:edit_translations_created.t(:tag => tag, :str => val)) if !@ajax
  end

  def change_translation(str, val)
    str.update_attributes!(
      :text => val,
      :modified => Time.now,
      :user => @user
    )
    str.update_localization
    flash_notice(:edit_translations_changed.t(:tag => str.tag, :str => val)) if !@ajax
  end

  def preview_string(str)
    str = @lang.clean_string(str)
    str = str.gsub(/\n/, ' / ')
    if str.length > 250
      str = str[0..250] + '...'
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

  def tags_to_show(tags, strings)
    hash = {}
    for tag3 in tags
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
        tag2,
        tag3,
      ]
        if strings[tag]
          hash[tag] = true
          break
        end
      end
    end
    return hash
  end

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
