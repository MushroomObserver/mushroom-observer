# frozen_string_literal: true

require "prawn/measurement_extensions"

class FieldSlipView
  include Prawn::View

  # Full page constants
  # Horizontal
  PAGE_LEFT = -27
  PAGE_RIGHT = 567
  X_OFFSET = -1.5
  PAGE_X_MID = X_OFFSET + PAGE_LEFT + (PAGE_RIGHT - PAGE_LEFT) / 2
  FONT_SIZE = 9
  NOTES_FONT_SIZE = 6

  # Vertical
  PAGE_BOTTOM = -27
  PAGE_TOP = 743

  # Offsets determined experimentally with a printer (EPSON ET-2760).
  # Need to test with more printers.  Could become variables.
  Y_OFFSET_1 = -4
  Y_OFFSET_2 = 4

  PAGE_Y_1_3RD = Y_OFFSET_1 + PAGE_BOTTOM + (PAGE_TOP - PAGE_BOTTOM) / 3
  PAGE_Y_2_3RDS = Y_OFFSET_2 + PAGE_BOTTOM + 2 * (PAGE_TOP - PAGE_BOTTOM) / 3

  # Slip constants
  RULER_WIDTH = 9.5.cm
  RULER_HEIGHT = 7.5.cm
  X_MIN = 0
  X_MAX = X_MIN + RULER_WIDTH
  Y_MAX = 244
  Y_MIN = Y_MAX - RULER_HEIGHT
  RULER_SIZE = 0.5.cm
  RULER_RIGHT = X_MIN + RULER_SIZE
  RULER_BOTTOM = Y_MAX - RULER_SIZE

  X_COORDS = [-18, 280].freeze
  Y_COORDS = [-27, 235, 500].freeze

  QR_SIZE = 174 * 72 / 300.0
  QR_LEFT = X_MIN + 0.75.cm
  QR_RIGHT = QR_LEFT + QR_SIZE
  QR_TOP = Y_MAX - 0.75.cm
  QR_BOTTOM = QR_TOP - QR_SIZE
  QR_MARGIN = 0.25.cm

  FIELD_HEIGHT = 1.cm

  LOGO_SIZE = 150 * 72 / 300
  LOGO_TOP = Y_MAX - 0.5.cm
  LOGO_BOTTOM = LOGO_TOP - LOGO_SIZE
  LOGO_LEFT = X_MIN + RULER_WIDTH - LOGO_SIZE - 2.5.mm

  # Other Codes box designed to fix 1.75" x 0.5" Avery label
  OTHER_WIDTH = 1.75.in
  OTHER_HEIGHT = 0.5.in
  CODE_WIDTH = ((RULER_WIDTH - OTHER_WIDTH) / 2) - QR_MARGIN
  OTHER_LEFT = CODE_WIDTH + 0.125.in
  CODE_MIN = 5.mm

  def initialize(title, prefix, logo, start, total)
    @title = title
    @prefix = prefix
    @logo = logo
    @start = start
    @total = total
  end

  def render
    cut_lines
    build_slips
  end

  private

  def document
    @document ||= Prawn::Document.new
  end

  def cut_lines
    stroke_color("C0C0C0")
    stroke do
      vertical_line(PAGE_BOTTOM, PAGE_TOP, at: PAGE_X_MID)
      horizontal_line(PAGE_LEFT, PAGE_RIGHT, at: PAGE_Y_1_3RD) # 223 + 1.mm)
      horizontal_line(PAGE_LEFT, PAGE_RIGHT, at: PAGE_Y_2_3RDS) # 489)
    end
    stroke_color("000000")
  end

  def build_slips
    (0..@total - 1).each do |i|
      x_index = i % 2
      y_index = 2 - (i / 2) % 3
      x = X_COORDS[x_index]
      y = Y_COORDS[y_index]
      num = (i + @start).to_s.rjust(5, "0")
      slip_at(x, y, "#{@prefix}-#{num}")
      if i % 6 == 5 && i < @total - 1
        start_new_page
        cut_lines
      end
    end
  end

  def slip_at(x_coord, y_coord, code)
    translate(x_coord, y_coord) do
      stroke do
        font_size(FONT_SIZE)
        header(code)
        footer(code)
        frame
        field("Date",
              RULER_RIGHT, QR_BOTTOM - QR_MARGIN,
              QR_RIGHT + QR_MARGIN, LOGO_BOTTOM - 2 * FIELD_HEIGHT)
        field("Collector",
              QR_RIGHT + QR_MARGIN, LOGO_BOTTOM,
              X_MAX, LOGO_BOTTOM - FIELD_HEIGHT)
        field("Location/Walk #",
              QR_RIGHT + QR_MARGIN, LOGO_BOTTOM - FIELD_HEIGHT,
              X_MAX, LOGO_BOTTOM - 2 * FIELD_HEIGHT)
        field("ID",
              RULER_RIGHT, Y_MIN + FIELD_HEIGHT,
              X_MAX, Y_MIN)
        id_by_boxes
        notes
      end
    end
  end

  def frame
    horizontal_ruler
    vertical_ruler
    rectangle([RULER_RIGHT, RULER_BOTTOM],
              RULER_WIDTH - RULER_SIZE, RULER_HEIGHT - RULER_SIZE)
  end

  def horizontal_ruler
    horizontal_line(X_MIN, X_MAX, at: RULER_BOTTOM)
    ruler_ticks([RULER_RIGHT, RULER_BOTTOM], [X_MAX, RULER_BOTTOM],
                [0, 5.mm], [1.cm, 0])
    ruler_ticks([RULER_RIGHT + 5.mm, RULER_BOTTOM], [X_MAX, RULER_BOTTOM],
                [0, 2.5.mm], [1.cm, 0])
  end

  def vertical_ruler
    vertical_line(Y_MAX, Y_MIN, at: RULER_RIGHT)
    ruler_ticks([RULER_RIGHT, Y_MIN], [RULER_RIGHT, RULER_BOTTOM],
                [-5.mm, 0], [0, 1.cm])
    ruler_ticks([RULER_RIGHT, Y_MIN + 5.mm], [RULER_RIGHT, RULER_BOTTOM],
                [-2.5.mm, 0], [0, 1.cm])
  end

  def ruler_ticks(start, finish, tick, offset)
    x = start[0]
    y = start[1]
    while x <= finish[0] && y <= finish[1]
      line([x, y], [x + tick[0], y + tick[1]])
      x += offset[0]
      y += offset[1]
    end
  end

  def header(str)
    qr_code(str)
    logo
  end

  def qr_code(code)
    title_width = 5.cm
    svg(qr_svg("http://mushroomobserver.org/qr/#{code}"), at: [QR_LEFT, QR_TOP],
                                                          width: QR_SIZE)
    font("#{Prawn::ManualBuilder::DATADIR}/fonts/DejaVuSans.ttf") do
      text_box("#{@title} Field Slip:",
               at: [QR_RIGHT + QR_MARGIN, QR_TOP],
               height: FONT_SIZE,
               width: title_width,
               overflow: :shrink_to_fit)
      text_box(code,
               at: [QR_RIGHT + QR_MARGIN, QR_TOP - FONT_SIZE * 1.5],
               height: FONT_SIZE,
               width: title_width,
               overflow: :shrink_to_fit)
    end
  end

  def qr_svg(path)
    qr = RQRCode::QRCode.new(path, level: :m)
    qr.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true,
      use_path: true,
      fill: :white
    )
  end

  def id_by_boxes
    box_size = 6.mm
    text_box("ID By:",
             at: [X_MAX - box_size * 2, Y_MIN + box_size + FONT_SIZE])
    rectangle([X_MAX - box_size * 3, Y_MIN + box_size], box_size, box_size)
    rectangle([X_MAX - box_size * 2, Y_MIN + box_size], box_size, box_size)
    rectangle([X_MAX - box_size, Y_MIN + box_size], box_size, box_size)
  end

  def notes
    notes_top = LOGO_BOTTOM - 2 * FIELD_HEIGHT
    notes_bottom = Y_MIN + FIELD_HEIGHT
    subnote_left = 5.cm
    subnote_indent = subnote_left + NOTES_FONT_SIZE
    field("Notes",
          RULER_RIGHT, notes_top,
          X_MAX, notes_bottom)
    font_size(NOTES_FONT_SIZE)
    current_y = notes_top - NOTES_FONT_SIZE
    text_box("Odor/taste:", at: [subnote_left, current_y])
    current_y -= NOTES_FONT_SIZE * 3
    text_box("Substrate: wood / soil / grass / dung",
             at: [subnote_left, current_y])
    current_y -= NOTES_FONT_SIZE
    text_box("Other:",
             at: [subnote_indent, current_y])
    current_y -= NOTES_FONT_SIZE * 3
    text_box("Plants: Hardwood / Conifer",
             at: [subnote_left, current_y])
    current_y -= NOTES_FONT_SIZE
    text_box("Species:",
             at: [subnote_indent, current_y])
    text_box("Habit: single / few / many",
             at: [RULER_RIGHT + NOTES_FONT_SIZE,
                  notes_bottom + NOTES_FONT_SIZE * 1.5])
    font_size(FONT_SIZE)
  end

  def field(title, left, top, right, bottom)
    text_offset = 1.mm
    rectangle([left, top], right - left, top - bottom)
    text_box("#{title}:", at: [left + text_offset, top - text_offset])
  end

  def footer(code)
    font("#{Prawn::ManualBuilder::DATADIR}/fonts/DejaVuSans.ttf") do
      text_box(code,
               at: [0, CODE_MIN],
               width: CODE_WIDTH,
               height: FONT_SIZE,
               overflow: :shrink_to_fit)
      field("Other Codes", OTHER_LEFT, Y_MIN, OTHER_LEFT + OTHER_WIDTH,
            Y_MIN - OTHER_HEIGHT)
      text_box(code,
               at: [OTHER_LEFT + OTHER_WIDTH + QR_MARGIN, CODE_MIN],
               width: CODE_WIDTH,
               height: FONT_SIZE,
               overflow: :shrink_to_fit)
    end
  end

  def logo
    x = LOGO_LEFT
    y = LOGO_TOP
    image(@logo, at: [x, y], height: LOGO_SIZE)
  end
end
