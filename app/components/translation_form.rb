# frozen_string_literal: true

# Phlex form for editing translation strings.
# Creates its own FormObject internally (Pattern B).
# Uses FieldProxy for dynamic textarea fields with flat param names.
class Components::TranslationForm < Components::ApplicationForm
  def initialize(lang:, tag:, edit_tags:,
                 strings:, **options)
    @lang = lang
    @tag = tag
    @edit_tags = edit_tags
    @strings = strings
    @for_page = options.delete(:for_page)
    @official_records = options.delete(:official_records)

    form_object = FormObject::Translation.new(tag: tag)
    super(form_object, **options)
  end

  def around_template(&block)
    render_official_section unless @lang.official
    @attributes[:data] =
      (@attributes[:data] || {}).merge(form_dataset)
    super
  end

  def view_template
    super do
      input(type: "hidden", name: "tag", value: @tag)
      render_language_header
      render_tag_textareas
      render_buttons
      render_locale_select
    end
  end

  private

  def form_action
    translation_path(@tag, for_page: @for_page)
  end

  def form_dataset
    {
      turbo: "true",
      controller: :translation,
      locale: @lang.locale,
      confirm_string:
        :edit_translations_will_lose_changes.l,
      loading_string: :edit_translations_loading.l,
      saving_string: :edit_translations_saving.l
    }
  end

  # --- Official language section (above form) ---

  def render_official_section
    div(id: "translation_official") do
      h4(class: "font-weight-bold") do
        plain("#{Language.official.name}:")
      end
      render_official_tags
      hr(class: "pb-1 pt-3")
    end
  end

  def render_official_tags
    @edit_tags.each do |ttag|
      record = @official_records[ttag]
      next unless record

      render_official_tag(ttag, record)
    end
  end

  def render_official_tag(ttag, record)
    span(class: "underline") { plain("#{ttag}:") }
    p do
      str = record.text.gsub("\\n", "\n")
      render_multiline_text(str)
    end
  end

  def render_multiline_text(str)
    str.split("\n", -1).each_with_index do |line, i|
      br if i.positive?
      plain(line)
    end
  end

  # --- Language header ---

  def render_language_header
    h4(class: "font-weight-bold mt-3") do
      plain("#{@lang.name}:")
    end
  end

  # --- Dynamic tag textareas ---

  def render_tag_textareas
    @edit_tags.each do |ttag|
      render_tag_textarea(ttag)
    end
  end

  def render_tag_textarea(ttag)
    str = @strings[ttag].to_s.gsub("\\n", "\n")
    rows = calculate_rows(str)
    notes = build_notes(ttag)

    proxy = build_field_proxy(ttag, str)
    comp = build_textarea_component(proxy, rows, ttag)
    set_between_slot(comp, notes)
    render(comp)
  end

  def build_field_proxy(ttag, str)
    Components::ApplicationForm::FieldProxy.new(
      nil, "tag_#{ttag}", str
    )
  end

  def build_textarea_component(proxy, rows, ttag)
    Components::ApplicationForm::TextareaField.new(
      proxy,
      attributes: {
        rows: rows,
        data: {
          translation_target: "textarea",
          action: "translation#formChanged"
        }
      },
      wrapper_options: { label: ttag }
    )
  end

  def set_between_slot(comp, notes)
    return unless notes.any?

    joined = notes.safe_join(", ")
    comp.with_between do
      span { plain("(#{joined})") }
    end
  end

  def calculate_rows(str)
    rows = 1
    str.each_line do |line|
      rows += (line.length / 80).truncate + 1
    end
    if rows < 2
      rows = @edit_tags.length > 1 ? 2 : 5
    end
    rows
  end

  def build_notes(ttag)
    [plurality_note(ttag), case_note(ttag)].compact
  end

  def plurality_note(ttag)
    if ttag.match(/s$/i) &&
       @edit_tags.include?(ttag.sub(/.$/, ""))
      :edit_translations_plural.t
    elsif @edit_tags.intersect?(["#{ttag}s", "#{ttag}S"])
      :edit_translations_singular.t
    end
  end

  def case_note(ttag)
    if ttag == ttag.upcase &&
       @edit_tags.include?(ttag.downcase)
      :edit_translations_uppercase.t
    elsif ttag == ttag.downcase &&
          @edit_tags.include?(ttag.upcase)
      :edit_translations_lowercase.t
    end
  end

  # --- Buttons ---

  def render_buttons
    div(class: "form-group") do
      render_save_button
      whitespace
      render_cancel_button
      whitespace
      render_reload_link
    end
  end

  def render_save_button
    button(
      type: :submit, name: :commit, value: :submit,
      id: "save_button", class: "btn btn-default",
      data: save_button_data
    ) { plain(:SAVE.l) }
  end

  def save_button_data
    {
      translation_target: "saveButton",
      action:
        "turbo:submit-start->translation#saving"
    }
  end

  def render_cancel_button
    button(
      type: :button, name: :commit, value: :cancel,
      id: "cancel_button",
      class: "btn btn-default",
      data: cancel_button_data
    ) { plain(:CANCEL.l) }
  end

  def cancel_button_data
    {
      translation_target: "cancelButton",
      action: "translation#clearForm"
    }
  end

  def render_reload_link
    a(
      href: edit_translation_path(
        id: @tag, locale: @lang.locale
      ),
      id: "reload_button", class: "btn btn-default",
      data: reload_link_data
    ) { plain(:RELOAD.l) }
  end

  def reload_link_data
    {
      tag: @tag,
      translation_target: "reloadButton",
      turbo_stream: "true"
    }
  end

  # --- Locale select ---

  def render_locale_select
    select(
      name: :locale,
      class: "form-control",
      data: locale_select_data
    ) do
      render_locale_options
    end
  end

  def locale_select_data
    {
      tag: @tag,
      translation_target: "localeSelect",
      action: "translation#changeLocale"
    }
  end

  def render_locale_options
    Language.menu_options.each do |name, locale|
      if locale == @lang.locale
        option(value: locale, selected: true) do
          plain(name)
        end
      else
        option(value: locale) { plain(name) }
      end
    end
  end
end
