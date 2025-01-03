# frozen_string_literal: true

class FieldSlipJobTracker < AbstractModel
  PUBLIC_DIR = "public/"
  SUBDIR = "shared"
  PDF_DIR = PUBLIC_DIR + SUBDIR

  enum status: [:Unstarted, :Starting, :Processing, :Done]

  belongs_to :user

  def self.create(*args)
    args[0][:status] = "Starting"
    super(*args)
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

  def filepath
    FileUtils.mkdir_p(PDF_DIR)
    @filepath ||= "#{PDF_DIR}/#{filename}"
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
