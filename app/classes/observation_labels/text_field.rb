# frozen_string_literal: true

# Represents a single field on a mushroom observation label
class ObservationLabels::TextField
  attr_reader :pdf, :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  # Renders the field as a formatted line on the PDF
  def render(pdf, _options = {})
    return if value.nil? || value.to_s.strip.empty?

    @pdf = pdf
    label_text = "#{name}: "
    label_width = calculate_label_width(label_text)

    # Draw the label
    draw_label(label_text)

    # Calculate available width for the value text
    available_width = pdf.bounds.width - label_width

    # Wrap and draw the value text
    draw_wrapped_value(value, label_width, available_width)

    # Move cursor down for next content
    # pdf.move_down(5)
  end

  private

  def calculate_label_width(label_text)
    width = 0
    pdf.font("app/assets/fonts/DejaVuSerif-Bold.ttf") do
      width = pdf.width_of(label_text, size: 10)
    end
    width
  end

  def draw_label(label_text)
    pdf.font("app/assets/fonts/DejaVuSerif-Bold.ttf") do
      pdf.draw_text(label_text, at: [0, pdf.cursor], size: 10)
    end
  end

  def draw_wrapped_value(text, label_width, available_width)
    lines = wrap_text(text, label_width, available_width)
    current_y = pdf.cursor

    lines.each_with_index do |line, index|
      # First line starts after label, others at left margin
      x_position = index.zero? ? label_width : 0

      pdf.font("app/assets/fonts/DejaVuSerif.ttf") do
        pdf.draw_text(line, at: [x_position, current_y], size: 10)
        current_y -= pdf.height_of("M", size: 10) # Move down by line height
      end
    end

    # Update cursor to final position
    pdf.move_cursor_to(current_y)
  end

  def wrap_text(text, label_width, available_width)
    lines = []
    words = text.split
    current_line = ""

    pdf.font("app/assets/fonts/DejaVuSerif.ttf") do
      words.each do |word|
        current_line = process_word(word, current_line, lines,
                                    label_width, available_width)
      end

      lines << current_line unless current_line.empty?
    end

    lines
  end

  def process_word(word, current_line, lines, label_width, available_width)
    test_line = current_line.empty? ? word : "#{current_line} #{word}"
    test_width = pdf.width_of(test_line, size: 10)

    if test_width <= available_width
      test_line
    else
      handle_line_overflow(word, current_line, lines, label_width,
                           available_width)
    end
  end

  def handle_line_overflow(word, current_line, lines, label_width,
                           available_width)
    available_width += label_width if lines.empty?
    lines << current_line unless current_line.empty?
    handle_oversized_word(word, lines, available_width)
  end

  def handle_oversized_word(word, lines, available_width)
    if pdf.width_of(word, size: 10) > available_width
      lines << word
      ""
    else
      word
    end
  end
end
