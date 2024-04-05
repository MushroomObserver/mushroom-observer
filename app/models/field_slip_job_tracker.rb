# frozen_string_literal: true

class FieldSlipJobTracker < AbstractModel
  PDF_DIR = "public/field_slips"

  enum status:
         {
           Starting: 1,
           Processing: 2,
           Done: 3
         }

  def self.create(*args)
    FileUtils.mkdir_p(PDF_DIR)
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
    @filename ||= "#{PDF_DIR}/#{prefix}-#{code_num(start)}-" \
                  "#{code_num(last)}-#{id}.pdf"
  end

  def description
    "#{status}: #{filename}"
  end

  private

  def code_num(num)
    num.to_s.rjust(5, "0")
  end
end
