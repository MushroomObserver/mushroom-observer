# Code that can be added observer_controller.rb to upload directory trees of images.

  JPEG_PAT = /\/([A-Za-z]+)\/([A-Za-z]+)\/([0-9-]+)-(.+).jpg$/
  MONTH_ONLY = /^[0-9]+-[0-9]+$/

  def find_image(what, who, date, fuzzy_date, filename, rel_path)
    notes = sprintf("Loaded from %s.", rel_path)
    if fuzzy_date
      notes += "\nThe date is only accurate to the month."
    end
    imgs = Image.find(:all,
                      :conditions =>["title = :what and owner = :who and notes = :notes",
                                     {:what => what, :who => who, :notes => notes}])
    image = nil
    if imgs == []
      image = Image.new
      image.created = Time.now
      image.modified = Time.now
      image.content_type = 'image/jpeg'
      image.title = what
      image.owner = who
      image.when = date
      image.notes = notes
      image.save
      File.copy filename, image.original_image
      image.create_resized_images
    else
      logger.warn(sprintf("%s has already been loaded", filename))
      image = imgs[0]
    end
    return image
  end

  def find_observation(what, who, date, fuzzy_date)
    notes = sprintf("Created because image(s) taken %s.", date)
    if fuzzy_date
      notes += "\nThe date is only accurate to the month."
    end
    obs = Observation.find(:all,
                           :conditions=>["what = :what and who = :who and notes = :notes",
                                         {:what => what, :who => who, :notes => notes}])
    observation = nil
    if obs == []
      observation = Observation.new
      observation.created = Time.now
      observation.modified = Time.now
      observation.when = date
      observation.who = who
      observation.where = 'Unknown'
      observation.what = what
      observation.specimen = false
      observation.notes = notes
      observation.save
    else
      logger.warn(sprintf("Observation matching (%s, %s, %s) already exists",
                          what, who, date))
      observation = obs[0]
    end
    return observation
  end

  def get_suffix(pat, f)
    result = f
    match = pat.match(f)
    if match
      result = match[1]
    end
    return result
  end

  def load_image_directory
    dir = '/Users/velosa/Fungi/big-import'
    pat = /^#{dir}\/(.+)$/
    who = 'Nathan Wilson'
    Find.find(dir) do |f|
      match = JPEG_PAT.match(f)
      if match:
        logger.warn(f)
        rel_path = get_suffix(pat, f)
        what = sprintf("%s %s", match[1], match[2])
        logger.warn(sprintf("%s: %s", f, match[3]))
        date_str = match[3]
        fuzzy_date = false
        if MONTH_ONLY.match(date_str)
          date_str += '-15'
          fuzzy_date = true
        end
        date = date_str.to_date
        image = find_image(what, who, date, fuzzy_date, f, rel_path)
        observation = find_observation(what, who, date, fuzzy_date)
        unless image.observations.member? observation
          image.observations << observation
        end
        unless observation.thumb_image
          logger.warn("***** Adding thumb_image *****")
          observation.thumb_image = image
          observation.save
        end
      end
    end
    redirect_to :action => 'list_observations'
  end
