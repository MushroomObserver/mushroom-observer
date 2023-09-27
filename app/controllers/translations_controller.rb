# frozen_string_literal: true

class TranslationsController < ApplicationController
  before_action :login_required

  def index
    @lang = set_language_and_authorize_user
    @ajax = false
    @for_page = params[:for_page]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    @show_tags = tags_to_show(@for_page, @strings)
    build_record_maps(@lang, @show_tags.keys + @edit_tags)
    @index = build_index(@lang, @show_tags)
  rescue StandardError => e
    raise(e) if Rails.env.test? && @lang

    flash_error(*error_message(e))
    redirect_back_or_default("/")
  end

  # ----------------------------
  #  :section: Edit Actions
  # ----------------------------

  # Form is only accessed by ajax from the index
  def edit
    @lang = set_language_and_authorize_user
    @ajax = true
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    build_record_maps(@lang, @edit_tags)
    render(partial: "translations/form")
  rescue StandardError => e
    msg = error_message(e).join("\n")
    render(plain: msg, status: :internal_server_error)
  end

  # Only accessed by ajax from the index
  def update
    @lang = set_language_and_authorize_user
    @ajax = true
    @tag = params[:commit] == :CANCEL.l ? nil : params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    build_record_maps(@lang, @edit_tags)
    update_translations(@edit_tags) if params[:commit] == :SAVE.l
    render(partial: "translations/ajax_post")
  rescue StandardError => e
    @error = error_message(e).join("\n")
    render(partial: "translations/ajax_error")
  end

  # -------------------------------
  #  :section: Supporting Methods
  # -------------------------------

  def error_message(error)
    msg = [error.to_s]
    if Rails.env.development? && @lang
      error.backtrace.each do |line|
        break if /action_controller.*perform_action/.match?(line)

        msg << line
      end
    end
    msg
  end

  def set_language_and_authorize_user
    locale = params[:locale] || I18n.locale
    lang = Language.find_by(locale: locale)
    validate_language_and_user(locale, lang)
    lang
  end

  def validate_language_and_user(locale, lang)
    raise(:edit_translations_bad_locale.t(locale: locale)) unless lang
    raise(:edit_translations_login_required.t) unless @user
    raise(:unsuccessful_contributor_warning.t) \
      unless @user.successful_contributor?
    raise(:edit_translations_reviewer_required.t) if lang.official && !reviewer?
  end

  def build_record_maps(lang, tags)
    @translated_records = build_record_map(lang, tags)
    @official_records = if lang.official
                          @translated_records
                        else
                          build_record_map(Language.official, tags)
                        end
  end

  def build_record_map(lang, _tags)
    result = {}
    # (If we just get the strings for the given tags, then it doesn't update
    # lang.translation_strings's cache correctly, and we have it end up loading
    # all the strings later, anyway!)
    lang.translation_strings.each do |str|
      result[str.tag] = str
    end
    result
  end

  def update_translations(tags)
    any_changes = false
    tags.each do |tag|
      old_val = @strings[tag].to_s
      new_val = begin
                  params["tag_#{tag}"].to_s
                rescue StandardError
                  ""
                end
      old_val = @lang.clean_string(old_val)
      new_val = @lang.clean_string(new_val)
      str = @translated_records[tag]
      if !str
        create_translation(tag, new_val)
        any_changes = true
      elsif old_val != new_val
        change_translation(str, new_val)
        any_changes = true
      else
        touch_translation(str)
      end
      @strings[tag] = new_val
    end
    if any_changes
      @lang.update_localization_file
      @lang.update_export_file
    else
      flash_warning(:edit_translations_no_changes.t) unless @ajax
    end
  end

  def create_translation(tag, val)
    str = @lang.translation_strings.create(tag: tag, text: val)
    @translated_records[tag] = str
    str.update_localization
    return if @ajax

    flash_notice(:edit_translations_created_at.t(tag: tag, str: val))
  end

  def change_translation(str, val)
    str.update!(text: val)
    str.update_localization
    return if @ajax

    flash_notice(:edit_translations_changed.t(tag: str.tag, str: val))
  end

  def touch_translation(str)
    str.update!(updated_at: Time.zone.now)
  end

  def preview_string(str, limit = 250)
    str = @lang.clean_string(str)
    str = str.gsub("\n", " / ")
    str = "#{str[0..limit]}..." if str.length > limit
    str
  end
  helper_method :preview_string

  def tags_to_edit(tag, strings)
    tag_list = []
    if tag.present?
      [tag, "#{tag}s", tag.upcase, "#{tag}s".upcase].each do |t|
        tag_list << t if strings.key?(t)
      end
      tag_list = [tag] if tag_list.empty?
    end
    tag_list
  end

  def tags_used_on_page(for_page)
    tag_list = nil
    if for_page.present?
      tag_list = Language.load_tags(for_page)
      flash_error(:edit_translations_page_expired.t) unless tag_list
    end
    tag_list
  end

  def tags_to_show(for_page, strings)
    hash = {}
    (tags_used_on_page(for_page) || strings.keys).each do |tag|
      primary = primary_tag(tag, strings)
      hash[primary] = true
    end
    hash
  end

  def primary_tag(tag3, strings)
    tag2 = "#{tag3}s"
    tag1 = tag3.sub(/s$/i, "")
    [
      tag1.downcase,
      tag2.downcase,
      tag3.downcase,
      tag1.upcase,
      tag2.upcase,
      tag3.upcase,
      tag1,
      tag2
    ].each do |tag|
      return tag if strings[tag]
    end
    tag3
  end

  # ----------------------------
  #  :section: Translation index
  # ----------------------------

  def build_index(lang, tags, file_handle = nil)
    @index = []
    @tags = tags
    @tags_used = {}
    file_handle ||= File.open(lang.export_file, "r:utf-8")
    reset_everything
    file_handle.each_line do |line|
      line.force_encoding("utf-8")
      process_template_line(line)
    end
    process_blank_line
    include_unlisted_tags
    file_handle.close if file_handle.respond_to?(:close)
    @index
  end

  def include_unlisted_tags
    unlisted_tags = @tags.keys - @tags_used.keys
    return if unlisted_tags.none?

    @index << TranslationsUIMajorHeader.new("UNLISTED STRINGS")
    @index << TranslationsUIMinorHeader.new(
      "These tags are missing from the export files."
    )
    unlisted_tags.sort.each do |tag|
      @index << TranslationsUITagField.new(tag)
    end
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
    if line =~ /^\s*['"]?(\w+)['"]?:\s*/
      tag = Regexp.last_match(1)
      str = Regexp.last_match.post_match
      process_tag_line(tag)
      @in_tag = true if str.start_with?(">")
    elsif @in_tag
      @in_tag = false unless /\S/.match?(line)
    elsif line.blank?
      process_blank_line
    elsif line =~ /^\s*#\s*(.*)/
      process_comment(Regexp.last_match(1))
    end
  end

  def process_tag_line(tag)
    @expecting_minor_head = false
    if @tags[tag]
      if @on_pages
        @do_section = true
      else
        add_headers
        @index << TranslationsUIComment.new(*@comments) if @comments.any?
        @index << TranslationsUITagField.new(tag)
      end
    end
    if @on_pages
      @section << TranslationsUIComment.new(*@comments) if @comments.any?
      if @comments.any? || !secondary_tag?(tag)
        @section << TranslationsUITagField.new(tag)
      end
    end
    @tags_used[tag] = true
    @comments.clear
  end

  def secondary_tag?(tag)
    @tags_used[tag.sub(/s$/i, "")] ||
      @tags_used[tag.downcase]
  end

  def process_blank_line
    if @on_pages
      if @do_section
        add_headers
        @index += @section
      end
      @section.clear
      @do_section = false
    end
    @minor_head = []
    @expecting_minor_head = true
  end

  def process_comment(str)
    if /#############/.match?(str)
      reset_everything
    elsif /^[A-Z][^a-z]*(--|$)/.match?(str)
      @major_head << str
      @on_pages = /PAGES/.match?(str)
    elsif @expecting_minor_head
      @minor_head << str
    else
      @comments << str
    end
  end

  def add_headers
    @index << TranslationsUIMajorHeader.new(*@major_head) if @major_head.any?
    @index << TranslationsUIMinorHeader.new(*@minor_head) if @minor_head.any?
    @major_head.clear
    @minor_head.clear
  end

  class TranslationsUIString
    attr_accessor :string

    def initialize(*strs)
      self.string = strs.join("\n")
    end
    alias to_s string
  end

  class TranslationsUIMajorHeader < TranslationsUIString
  end

  class TranslationsUIMinorHeader < TranslationsUIString
  end

  class TranslationsUIComment < TranslationsUIString
  end

  class TranslationsUITagField < TranslationsUIString
    alias tag string
  end
end
