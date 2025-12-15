# frozen_string_literal: true

class FieldSlipJobTracker < AbstractModel
  PUBLIC_DIR = "public/"
  SUBDIR = "shared"
  PDF_DIR = PUBLIC_DIR + SUBDIR

  enum :status, { Starting: 1, Processing: 2, Done: 3 }

  belongs_to :user

  # Returns the PDF directory to use. Can be overridden in subclasses or tests.
  def self.pdf_directory
    PDF_DIR
  end

  def self.create(*args)
    args[0][:status] = "Starting"
    super
  end

  def last
    start + count - 1
  end

  def processing
    self.status = "Processing"
    save
  end

  def done
    self.status = "Done"
    save
  end

  def filename
    @filename ||= "#{prefix}-#{code_num(start)}-#{code_num(last)}-#{id}.pdf"
  end

  def pdf_dir
    self.class.pdf_directory
  end

  def filepath
    dir = pdf_dir
    # Cache the filepath but only if the directory hasn't changed
    # This allows tests to stub the directory while maintaining performance
    if @cached_dir == dir
      @filepath
    else
      FileUtils.mkdir_p(dir)
      @cached_dir = dir
      @filepath = "#{dir}/#{filename}"
    end
  end

  def link
    "#{MO.http_domain}/#{SUBDIR}/#{filename}"
  end

  def elapsed_time
    if status == "Done"
      updated_at - created_at
    else
      Time.zone.now - created_at
    end
  end

  private

  def code_num(num)
    num.to_s.rjust(5, "0")
  end
end
