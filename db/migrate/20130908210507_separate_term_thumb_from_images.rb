class SeparateTermThumbFromImages < ActiveRecord::Migration[4.2]
  def self.up
    Term.record_timestamps = false
    # for term in Term.find(:all) # Rails 3
    for term in Term.all
      if term.images.member?(term.thumb_image)
        term.images.delete(term.thumb_image)
        term.save_without_our_callbacks
      end
    end
    Term.record_timestamps = true
  end

  def self.down
    Term.record_timestamps = false
    # for term in Term.find(:all) # Rails 3
    for term in Term.all
      if term.thumb_image
        term.images.push(term.thumb_image)
        term.save_without_our_callbacks
      end
    end
    Term.record_timestamps = true
  end
end
