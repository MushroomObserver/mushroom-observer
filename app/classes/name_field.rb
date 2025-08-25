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

    debugger
    x_start = render_field_label(pdf, options)
    render_field_content(pdf, x_start)
  end

  private

  def render_field_label(pdf, options)
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
    if word.include?(' ')
      parts = word.split(' ')
      parts.each_with_index do |part, index|
        add_plain_text_token(tokens, part) if part.length.positive?
        add_plain_text_token(tokens, ' ') if index < parts.length - 1
      end
    else
      add_plain_text_token(tokens, word) if word.length.positive?
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
      current_pos = process_nested_character(text, tokens, base_styles, current_pos)
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
    if word.include?(' ')
      parts = word.split(' ')
      parts.each_with_index do |part, index|
        tokens << [part, base_styles] if part.length.positive?
        tokens << [' ', base_styles] if index < parts.length - 1
      end
    else
      tokens << [word, base_styles] if word.length.positive?
    end
    
    word_end
  end

  def add_styled_words(tokens, text, styles)
    # Split by spaces and add each word with appropriate spacing
    words = text.split(' ')
    words.each_with_index do |word, index|
      tokens << [word, styles] if word.length.positive?
      tokens << [' ', styles] if index < words.length - 1
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
    current_line_height = pdf.font_size * 1.2
    x_position = x_start
    y_position = pdf.cursor

    tokens.each do |text, styles|
      next if text.strip.empty?
      
      font_file = determine_font_style(styles)
      
      # Calculate text width with the specific font
      text_width = nil
      pdf.font(font_file) do
        text_width = pdf.width_of(text, size: 10)
      end
      
      # Check if we need to wrap to next line
      if x_position + text_width > pdf.bounds.width
        y_position -= current_line_height
        x_position = 0
      end
      
      # Draw the text at the calculated position with specific font
      pdf.font(font_file) do
        pdf.draw_text(text, at: [x_position, y_position], size: 10)
      end
      
      x_position += text_width + pdf.width_of(" ", size: 10)
    end
    
    # Move cursor to below the rendered content
    pdf.move_cursor_to(y_position - current_line_height)
  end

  def render_single_token(pdf, text, styles, x_position)
    font_file = determine_font_style(styles)
    text_width = calculate_text_width(pdf, text, font_file)
    
    x_position = handle_line_wrapping(pdf, x_position, text_width)
    draw_styled_text(pdf, text, font_file, x_position)
    
    x_position + text_width
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

  def render_single_token(pdf, text, styles, x_position)
    font_style = determine_font_style(styles)
    text_width = calculate_text_width(pdf, text)
    
    x_position = handle_line_wrapping(pdf, x_position, text_width)
    draw_styled_text(pdf, text, font_style, x_position)
    
    x_position + text_width
  end

  def calculate_text_width(pdf, text, font_file = "app/assets/fonts/DejaVuSerif.ttf")
    # Calculate width using the specific font
    width = nil
    pdf.font(font_file) do
      width = pdf.width_of(text, size: 10)
    end
    width
  end

  def handle_line_wrapping(pdf, x_position, text_width)
    if x_position + text_width > pdf.bounds.width
      pdf.move_down(pdf.font_size * 1.2)
      0
    else
      x_position
    end
  end

  def draw_styled_text(pdf, text, font_file, x_position)
    pdf.font(font_file) do
      pdf.draw_text(text, at: [x_position, pdf.cursor], size: 10)
    end
  end
end
