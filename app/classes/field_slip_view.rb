# frozen_string_literal: true

require "prawn/measurement_extensions"

class FieldSlipView
  include Prawn::View
  include Prawn::FieldSlipCard

  # Full page constants
  SLIPS_PER_PAGE = 6

  # Horizontal
  PAGE_LEFT = -27
  PAGE_RIGHT = 567
  X_OFFSET = -1.5
  PAGE_X_MID = X_OFFSET + PAGE_LEFT + (PAGE_RIGHT - PAGE_LEFT) / 2

  # Vertical
  PAGE_BOTTOM = -27
  PAGE_TOP = 743

  # Offsets determined experimentally with a printer (EPSON ET-2760).
  # Need to test with more printers.  Could become variables.
  Y_OFFSET_1 = -4
  Y_OFFSET_2 = 4

  PAGE_Y_1_3RD = Y_OFFSET_1 + PAGE_BOTTOM + (PAGE_TOP - PAGE_BOTTOM) / 3
  PAGE_Y_2_3RDS = Y_OFFSET_2 + PAGE_BOTTOM + 2 * (PAGE_TOP - PAGE_BOTTOM) / 3

  X_COORDS = [-18, 280].freeze
  Y_COORDS = [-27, 235, 500].freeze

  ONE_PAGE_X = 612.0 / 2
  ONE_PAGE_Y = 792.0 / 3

  def initialize(tracker, logo)
    @tracker = tracker
    @logo = logo
  end

  def render
    cut_lines
    build_slips
  end

  private

  def page_size
    @page_size ||= @tracker.one_per_page ? [ONE_PAGE_X, ONE_PAGE_Y] : "LETTER"
  end

  def document
    @document ||= Prawn::Document.new(page_size: page_size)
  end

  def cut_lines
    return if @tracker.one_per_page

    stroke_color("C0C0C0")
    stroke do
      vertical_line(PAGE_BOTTOM, PAGE_TOP, at: PAGE_X_MID)
      horizontal_line(PAGE_LEFT, PAGE_RIGHT, at: PAGE_Y_1_3RD) # 223 + 1.mm)
      horizontal_line(PAGE_LEFT, PAGE_RIGHT, at: PAGE_Y_2_3RDS) # 489)
    end
    stroke_color("000000")
  end

  def build_slips
    (0..@tracker.count - 1).each do |i|
      num = (i + @tracker.start).to_s.rjust(5, "0")
      slip_at(slip_left(i), slip_bottom(i), "#{@tracker.prefix}-#{num}")
      new_page_check(i)
    end
    @tracker.pages += 1
    @tracker.save
  end

  def slip_left(slip_num)
    if @tracker.one_per_page
      X_COORDS[0]
    else
      X_COORDS[slip_num % 2]
    end
  end

  def slip_bottom(slip_num)
    if @tracker.one_per_page
      Y_COORDS[0]
    else
      Y_COORDS[2 - (slip_num / 2) % 3]
    end
  end

  def new_page_check(slip_num)
    return unless last_slip?(slip_num) && more_pages?(slip_num)

    @tracker.pages += 1
    @tracker.save
    start_new_page(size: page_size)
    cut_lines
  end

  def last_slip?(slip_num)
    @tracker.one_per_page || (slip_num % SLIPS_PER_PAGE == SLIPS_PER_PAGE - 1)
  end

  def more_pages?(slip_num)
    slip_num < @tracker.count - 1
  end
end
