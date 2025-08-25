# frozen_string_literal: true

# Represents a taxonomic name field with proper formatting for
# scientific names Handles Textile markup (**bold** and __italic__)
# and renders with appropriate font styling
class NameField
  attr_reader :name, :value, :tokens

  def initialize(name, textile_value)
    @name = name
    @value = textile_value
    @tokens = parse_textile(textile_value)
  end

  # Renders the name field with proper taxonomic formatting
  def render(pdf, options = {})
    return if value.nil? || value.to_s.strip.empty?

    x_start = render_field_label(pdf, options)
    render_field_content(pdf, x_start)
  end

  private

  def render_field_label(pdf, _options)
    label_text = "#{name}: "

    # Calculate width using the bold font
    label_width = nil
    pdf.font("app/assets/fonts/DejaVuSerif-Bold.ttf") do
      label_width = pdf.width_of(label_text, size: 10)
      pdf.draw_text(label_text, at: [0, pdf.cursor], size: 10)
    end

    label_width
  end

  def render_field_content(pdf, x_start)
    # Render content on the next line instead of trying to position inline
    render_tokens(pdf, tokens, x_start)
  end

  def parse_textile(textile_text)
    return [] if textile_text.nil? || textile_text.strip.empty?

    tokens = []
    current_pos = 0
    text = textile_text.dup

    process_textile_formatting(text, tokens, current_pos)
    tokens
  end

  def process_textile_formatting(text, tokens, current_pos)
    while current_pos < text.length
      new_pos = process_next_character(text, tokens, current_pos)
      # Ensure we always advance to prevent infinite loops
      current_pos = new_pos > current_pos ? new_pos : current_pos + 1
    end
    current_pos
  end

  def process_next_character(text, tokens, current_pos)
    if bold_marker_at?(text, current_pos)
      process_bold_formatting(text, tokens, current_pos)
    elsif italic_marker_at?(text, current_pos)
      process_italic_formatting(text, tokens, current_pos)
    else
      process_regular_text(text, tokens, current_pos)
    end
  end

  def bold_marker_at?(text, pos)
    text[pos, 2] == "**"
  end

  def italic_marker_at?(text, pos)
    text[pos, 2] == "__"
  end

  def process_bold_formatting(text, tokens, current_pos)
    end_pos = find_matching_marker(text, current_pos + 2, "**")
    if end_pos
      bold_text = text[current_pos + 2, end_pos - current_pos - 2]
      bold_tokens = parse_nested_formatting(bold_text, [:bold])
      tokens.concat(bold_tokens)
      end_pos + 2
    else
      add_plain_text_token(tokens, text[current_pos])
      current_pos + 1
    end
  end

  def process_italic_formatting(text, tokens, current_pos)
    end_pos = find_matching_marker(text, current_pos + 2, "__")
    if end_pos
      italic_text = text[current_pos + 2, end_pos - current_pos - 2]
      italic_tokens = parse_nested_formatting(italic_text, [:italic])
      tokens.concat(italic_tokens)
      end_pos + 2
    else
      add_plain_text_token(tokens, text[current_pos])
      current_pos + 1
    end
  end

  def process_regular_text(text, tokens, current_pos)
    word_end = find_word_boundary(text, current_pos)
    word = text[current_pos, word_end - current_pos]

    # Split word by spaces to handle individual words
    if word.include?(" ")
      parts = word.split
      parts.each_with_index do |part, index|
        add_plain_text_token(tokens, part) if part.length.positive?
        add_plain_text_token(tokens, " ") if index < parts.length - 1
      end
    elsif word.length.positive?
      add_plain_text_token(tokens, word)
    end

    word_end
  end

  def add_plain_text_token(tokens, text)
    tokens << [text, []]
  end

  def parse_nested_formatting(text, base_styles)
    tokens = []
    current_pos = 0

    while current_pos < text.length
      current_pos = process_nested_character(text, tokens, base_styles,
                                             current_pos)
    end

    tokens
  end

  def process_nested_character(text, tokens, base_styles, current_pos)
    if can_apply_bold?(text, current_pos, base_styles)
      process_nested_bold(text, tokens, base_styles, current_pos)
    elsif can_apply_italic?(text, current_pos, base_styles)
      process_nested_italic(text, tokens, base_styles, current_pos)
    else
      process_nested_regular_text(text, tokens, base_styles, current_pos)
    end
  end

  def can_apply_bold?(text, pos, base_styles)
    bold_marker_at?(text, pos) && base_styles.exclude?(:bold)
  end

  def can_apply_italic?(text, pos, base_styles)
    italic_marker_at?(text, pos) && base_styles.exclude?(:italic)
  end

  def process_nested_bold(text, tokens, base_styles, current_pos)
    end_pos = find_matching_marker(text, current_pos + 2, "**")
    if end_pos
      bold_text = text[current_pos + 2, end_pos - current_pos - 2]
      add_styled_words(tokens, bold_text, base_styles + [:bold])
      end_pos + 2
    else
      tokens << [text[current_pos], base_styles]
      current_pos + 1
    end
  end

  def process_nested_italic(text, tokens, base_styles, current_pos)
    end_pos = find_matching_marker(text, current_pos + 2, "__")
    if end_pos
      italic_text = text[current_pos + 2, end_pos - current_pos - 2]
      add_styled_words(tokens, italic_text, base_styles + [:italic])
      end_pos + 2
    else
      tokens << [text[current_pos], base_styles]
      current_pos + 1
    end
  end

  def process_nested_regular_text(text, tokens, base_styles, current_pos)
    word_end = find_word_boundary(text, current_pos)
    word = text[current_pos, word_end - current_pos]

    # Split word by spaces to handle individual words
    if word.include?(" ")
      parts = word.split
      parts.each_with_index do |part, index|
        tokens << [part, base_styles] if part.length.positive?
        tokens << [" ", base_styles] if index < parts.length - 1
      end
    elsif word.length.positive?
      tokens << [word, base_styles]
    end

    word_end
  end

  def add_styled_words(tokens, text, styles)
    # Split by spaces and add each word with appropriate spacing
    words = text.split
    words.each_with_index do |word, index|
      tokens << [word, styles] if word.length.positive?
      tokens << [" ", styles] if index < words.length - 1
    end
  end

  def find_matching_marker(text, start_pos, marker)
    text.index(marker, start_pos)
  end

  def find_word_boundary(text, start_pos)
    pos = start_pos
    while pos < text.length
      return pos if at_word_boundary?(text, pos)

      pos += 1
    end
    pos
  end

  def at_word_boundary?(text, pos)
    char = text[pos]
    next_char = pos + 1 < text.length ? text[pos + 1] : nil

    whitespace_character?(char) || formatting_marker?(char, next_char)
  end

  def whitespace_character?(char)
    [" ", "\t", "\n"].include?(char)
  end

  def formatting_marker?(char, next_char)
    (char == "*" && next_char == "*") || (char == "_" && next_char == "_")
  end

  def can_merge_with_previous?(merged, styles)
    !merged.empty? && merged.last[1] == styles
  end

  def render_tokens(pdf, tokens, x_start)
    position = {
      x: x_start,
      y: pdf.cursor,
      line_height: pdf.font_size * 1.2
    }

    tokens.each do |text, styles|
      next if text.strip.empty?

      position = render_single_token(pdf, text, styles, position)
    end

    final_y = position[:y] - position[:line_height]
    pdf.move_cursor_to(final_y)
  end

  def render_single_token(pdf, text, styles, position)
    font_file = determine_font_style(styles)
    text_metrics = calculate_text_metrics(pdf, text, font_file)

    position = handle_line_wrapping(pdf, position, text_metrics)

    pdf.font(font_file) do
      pdf.draw_text(text, at: [position[:x], position[:y]], size: 10)
    end

    advance_position(pdf, position, text_metrics)
  end

  def calculate_text_metrics(pdf, text, font_file)
    metrics = {}
    pdf.font(font_file) do
      metrics[:width] = pdf.width_of(text, size: 10)
      metrics[:height] = pdf.height_of(text, size: 10)
    end
    metrics
  end

  def handle_line_wrapping(pdf, position, text_metrics)
    text_width = text_metrics[:width]

    if position[:x] + text_width > pdf.bounds.width
      {
        x: 0,
        y: position[:y] - position[:line_height],
        line_height: position[:line_height]
      }
    else
      position
    end
  end

  def advance_position(pdf, position, text_metrics)
    space_width = pdf.width_of(" ", size: 10)

    {
      x: position[:x] + text_metrics[:width] + space_width,
      y: position[:y],
      line_height: text_metrics[:height]
    }
  end

  def determine_font_style(styles)
    # Return font file path based on styles
    if styles.include?(:bold) && styles.include?(:italic)
      "app/assets/fonts/DejaVuSerif-BoldItalic.ttf"
    elsif styles.include?(:bold)
      "app/assets/fonts/DejaVuSerif-Bold.ttf"
    elsif styles.include?(:italic)
      "app/assets/fonts/DejaVuSerif-Italic.ttf"
    else
      "app/assets/fonts/DejaVuSerif.ttf"
    end
  end
end
