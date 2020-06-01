# frozen_string_literal: true

class TranslationsController < ApplicationController
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
  rescue StandardError => e
    raise e if Rails.env.test? && @lang

    flash_error(*error_message(e))
    redirect_back_or_default("/")
  end

  def edit_translations_ajax_get # :norobots:
    @lang = get_language_and_authorize_user
    @ajax = true
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    get_record_maps(@lang, @edit_tags)
    render(partial: "form")
  rescue StandardError => e
    msg = error_message(e).join("\n")
    render(plain: msg, status: :internal_server_error)
  end

  def edit_translations_ajax_post # :norobots:
    @lang = get_language_and_authorize_user
    @ajax = true
    @tag = params[:tag]
    @strings = @lang.localization_strings
    @edit_tags = tags_to_edit(@tag, @strings)
    get_record_maps(@lang, @edit_tags)
    update_translations(@edit_tags)
    render(partial: "ajax_post")
  rescue StandardError => e
    @error = error_message(e).join("\n")
    render(partial: "ajax_error")
  end

  # -------------------------------
  #  :section: Supporting Methods
  # -------------------------------

  def error_message(error)
    msg = [error.to_s]
    if Rails.env.development? && @lang
      for line in error.backtrace
        break if /action_controller.*perform_action/.match?(line)

        msg << line
      end
    end
    msg
  end

  def get_language_and_authorize_user
    locale = params[:locale] || I18n.locale
    lang = Language.find_by_locale(locale)
    validate_language_and_user(locale, lang)
    lang
  end

  def validate_language_and_user(locale, lang)
    if !lang
      raise(:edit_translations_bad_locale.t(locale: locale))
    elsif !@user
      raise(:edit_translations_login_required.t)
    elsif !@user.is_successful_contributor?
      raise(:unsuccessful_contributor_warning.t)
    elsif lang.official && !reviewer?
      raise(:edit_translations_reviewer_required.t)
    end
  end

  def get_record_maps(lang, tags)
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
    for str in lang.translation_strings
      result[str.tag] = str
    end
    result
  end

  def update_translations(tags)
    any_changes = false
    for tag in tags
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
      elsif
        touch_translation(str) # rubocop:disable Layout/ConditionPosition
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
    str = str.gsub(/\n/, " / ")
    str = str[0..limit] + "..." if str.length > limit
    str
  end
  helper_method :preview_string

  def tags_to_edit(tag, strings)
    tag_list = []
    if tag.present?
      for t in [tag, tag + "s", tag.upcase, (tag + "s").upcase]
        tag_list << t if strings.key?(t)
      end
      tag_list = [tag] if tag_list.empty?
    end
    tag_list
  end

  def tags_used_on_page(page)
    tag_list = nil
    if page.present?
      tag_list = Language.load_tags(page)
      flash_error(:edit_translations_page_expired.t) unless tag_list
    end
    tag_list
  end

  def tags_to_show(page, strings)
    hash = {}
    for tag in tags_used_on_page(page) || strings.keys
      primary = primary_tag(tag, strings)
      hash[primary] = true
    end
    hash
  end

  def primary_tag(tag3, strings)
    tag2 = tag3 + "s"
    tag1 = tag3.sub(/s$/i, "")
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
    tag3
  end

  # ----------------------------
  #  :section: Edit Form
  # ----------------------------

  def build_form(lang, tags, file_handle = nil)
    @form = []
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
    @form
  end

  def include_unlisted_tags
    unlisted_tags = @tags.keys - @tags_used.keys
    return if unlisted_tags.none?

    @form << TranslationFormMajorHeader.new("UNLISTED STRINGS")
    @form << TranslationFormMinorHeader.new(
      "These tags are missing from the export files."
    )
    unlisted_tags.sort.each do |tag|
      @form << TranslationFormTagField.new(tag)
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
      str = $'
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
        @form << TranslationFormComment.new(*@comments) if @comments.any?
        @form << TranslationFormTagField.new(tag)
      end
    end
    if @on_pages
      @section << TranslationFormComment.new(*@comments) if @comments.any?
      if @comments.any? || !secondary_tag?(tag)
        @section << TranslationFormTagField.new(tag)
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
        @form += @section
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
      @on_pages = !!/PAGES/.match?(str)
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
