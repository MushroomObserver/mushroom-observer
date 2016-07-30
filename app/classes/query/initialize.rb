module Query::Initialize
  def initialize_model_do_boolean(arg, true_cond, false_cond)
    where << (params[arg] ? true_cond : false_cond) unless params[arg].nil?
  end

  def initialize_model_do_search(arg, col = nil)
    unless params[arg].blank?
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      search = google_parse(params[arg])
      self.where += google_conditions(search, col)
    end
  end

  def initialize_model_do_range(arg, col, args = {})
    if params[arg].is_a?(Array)
      min, max = params[arg]
      self.where << "#{col} >= #{min}" unless min.blank?
      self.where << "#{col} <= #{max}" unless max.blank?
      if (join = args[:join]) &&
         (!min.blank? || !max.blank?)
        # TODO: is this used? convert to piecewise add_join
        self.join << join
      end
    end
  end

  def initialize_model_do_enum_set(arg, col, vals, type)
    unless params[arg].blank?
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      types = params[arg].to_s.strip_squeeze.split
      if type == :string
        types &= vals.map(&:to_s)
        self.where << "#{col} IN ('#{types.join("','")}')" if types.any?
      elsif
        types.map! { |v| vals.index_of(v.to_sym) }.reject!(&:nil?)
        self.where << "#{col} IN (#{types.join(",")})" if types.any?
      end
    end
  end

  def initialize_model_do_deprecated
    case params[:deprecated] || :either
    when :no then self.where << "names.deprecated IS FALSE"
    when :only then self.where << "names.deprecated IS TRUE"
    end
  end

  def initialize_model_do_misspellings
    case params[:misspellings] || :no
    when :no then self.where << "names.correct_spelling_id IS NULL"
    when :only then self.where << "names.correct_spelling_id IS NOT NULL"
    end
  end

  def initialize_model_do_objects_by_id(arg, col = nil)
    if ids = params[arg]
      col ||= "#{arg.to_s.sub(/s$/, "")}_id"
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      set = clean_id_set(ids)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_objects_by_name(model, arg, col = nil, args = {})
    names = params[arg]
    if names && names.any?
      col ||= arg.to_s.sub(/s?$/, "_id")
      col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
      objs = []
      for name in names
        if name.to_s.match(/^\d+$/)
          obj = model.safe_find(name)
          objs << obj if obj
        else
          case model.name
          when "Location"
            pattern = clean_pattern(Location.clean_name(name))
            #            objs += model.all(:conditions => "name LIKE '%#{pattern}%'") # Rails 3
            objs += model.where("name LIKE ?", "%#{pattern}%")
          when "Name"
            if parse = Name.parse_name(name)
              name2 = parse.search_name
            else
              name2 = Name.clean_incoming_string(name)
            end
            matches = model.where(search_name: name2)
            matches = model.where(text_name: name2) if matches.empty?
            objs += matches
          when "Project", "SpeciesList"
            objs += model.where(title: name)
          when "User"
            name.sub(/ *<.*>/, "")
            objs += model.where(login: name)
          else
            fail("Forgot to tell initialize_model_do_objects_by_name how " \
                  "to find instances of #{model.name}!")
          end
        end
      end
      if filter = args[:filter]
        objs = objs.uniq.map(&filter).flatten
      end
      if join = args[:join]
        # TODO: is this used? convert to piecewise add_join
        self.join << join
      end
      set = clean_id_set(objs.map(&:id).uniq)
      self.where << "#{col} IN (#{set})"
    end
  end

  def initialize_model_do_locations(table = model_class.table_name, args = {})
    locs = params[:locations]
    if locs && locs.any?
      loc_col = "#{table}.location_id"
      initialize_model_do_objects_by_name(Location, :locations, loc_col, args)
      str = self.where.pop
      for name in locs
        if name.match(/\D/)
          pattern = clean_pattern(name)
          str += " OR #{table}.where LIKE '%#{pattern}%'"
        end
      end
      self.where << str
    end
  end

  def initialize_model_do_bounding_box(type)
    if params[:north]
      n, s, e, w = params.values_at(:north, :south, :east, :west)
      if w < e
        cond1 = [
          "observations.lat >= #{s}",
          "observations.lat <= #{n}",
          "observations.long >= #{w}",
          "observations.long <= #{e}"
        ]
        cond2 = [
          "locations.south >= #{s}",
          "locations.north <= #{n}",
          "locations.west >= #{w}",
          "locations.east <= #{e}",
          "locations.west <= locations.east"
        ]
      else
        cond1 = [
          "observations.lat >= #{s}",
          "observations.lat <= #{n}",
          "(observations.long >= #{w} OR observations.long <= #{e})"
        ]
        cond2 = [
          "locations.south >= #{s}",
          "locations.north <= #{n}",
          "locations.west >= #{w}",
          "locations.east <= #{e}",
          "locations.west > locations.east"
        ]
      end
      if type == :location
        self.where += cond2
      else
        # Condition which returns true if the observation's lat/long is plausible.
        # (should be identical to BoxMethods.lat_long_close?)
        cond0 = %(
          observations.lat >= locations.south * 1.2 - locations.north * 0.2 AND
          observations.lat <= locations.north * 1.2 - locations.south * 0.2 AND
          if(locations.west <= locations.east,
            observations.long >= locations.west * 1.2 - locations.east * 0.2 AND
            observations.long <= locations.east * 1.2 - locations.west * 0.2,
            observations.long >= locations.west * 0.8 + locations.east * 0.2 + 72 OR
            observations.long <= locations.east * 0.8 + locations.west * 0.2 - 72
          )
        )
        cond1 = cond1.join(" AND ")
        cond2 = cond2.join(" AND ")
        # TODO: not sure how to deal with the bang notation -- indicates LEFT
        # OUTER JOIN instead of normal INNER JOIN.
        join << :"locations!" unless uses_join?(:locations)
        self.where << "IF(locations.id IS NULL OR #{cond0}, #{cond1}, #{cond2})"
      end
    end
  end

  def initialize_model_do_rank
    unless params[:rank].blank?
      min, max = params[:rank]
      max ||= min
      all_ranks = Name.all_ranks
      a = all_ranks.index(min) || 0
      b = all_ranks.index(max) || (all_ranks.length - 1)
      a, b = b, a if a > b
      ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
      self.where << "names.rank IN (#{ranks.join(",")})"
    end
  end

  def initialize_model_do_image_size
    if params[:size]
      min, max = params[:size]
      sizes  = Image.all_sizes
      pixels = Image.all_sizes_in_pixels
      if min
        size = pixels[sizes.index(min)]
        self.where << "images.width >= #{size} OR images.height >= #{size}"
      end
      if max
        size = pixels[sizes.index(max) + 1]
        self.where << "images.width < #{size} AND images.height < #{size}"
      end
    end
  end

  def initialize_model_do_image_types
    unless params[:content_types].blank?
      exts  = Image.all_extensions.map(&:to_s)
      mimes = Image.all_content_types.map(&:to_s) - [""]
      types = params[:types].to_s.strip_squeeze.split & exts
      if types.any?
        other = types.include?("raw")
        types -= ["raw"]
        types = types.map { |x| mimes[exts.index(x)] }
        str1 = "comments.target_type IN ('#{types.join("','")}')"
        str2 = "comments.target_type NOT IN ('#{mimes.join("','")}')"
        if types.empty?
          self.where << str2
        elsif other
          self.where << "#{str1} OR #{str2}"
        else
          self.where << str1
        end
      end
    end
  end

  def initialize_model_do_license
    unless params[:license].blank?
      license = find_cached_parameter_instance(License, :license)
      self.where << "#{model_class.table_name}.license_id = #{license.id}"
    end
  end

  # ----------------------------
  #  Date customization.
  # ----------------------------

  def initialize_model_do_date(arg = :date, col = arg)
    col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
    if vals = params[arg]
      # Ugh, special case for search by month/day where range of months wraps around from December to January.
      if vals[0].to_s.match(/^\d\d-\d\d$/) &&
         vals[1].to_s.match(/^\d\d-\d\d$/) &&
         vals[0].to_s > vals[1].to_s
        m1, d1 = vals[0].to_s.split("-")
        m2, d2 = vals[1].to_s.split("-")
        self.where << "MONTH(#{col}) > #{m1} OR MONTH(#{col}) < #{m2} OR " \
                      "(MONTH(#{col}) = #{m1} AND DAY(#{col}) >= #{d1}) OR " \
                      "(MONTH(#{col}) = #{m2} AND DAY(#{col}) <= #{d2})"
      else
        initialize_model_do_date_half(true, vals[0], col)
        initialize_model_do_date_half(false, vals[1], col)
      end
    end
  end

  def initialize_model_do_date_half(min, val, col)
    dir = min ? ">" : "<"
    if val.to_s.match(/^\d\d\d\d/)
      y, m, d = val.split("-")
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      self.where << "#{col} #{dir}= '%04d-%02d-%02d'" % [y, m, d].map(&:to_i)
    elsif val.to_s.match(/-/)
      m, d = val.split("-")
      self.where << "MONTH(#{col}) #{dir} #{m} OR " \
                    "(MONTH(#{col}) = #{m} AND " \
                    "DAY(#{col}) #{dir}= #{d})"
    elsif !val.blank?
      self.where << "MONTH(#{col}) #{dir}= #{val}"
      # XXX This fails if start month > end month XXX
    end
  end

  def initialize_model_do_time(arg = :time, col = arg)
    col = "#{model_class.table_name}.#{col}" unless col.to_s.match(/\./)
    if vals = params[arg]
      initialize_model_do_time_half(true, vals[0], col)
      initialize_model_do_time_half(false, vals[1], col)
    end
  end

  def initialize_model_do_time_half(min, val, col)
    unless val.blank?
      dir = min ? ">" : "<"
      y, m, d, h, n, s = val.split("-")
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      h ||= min ? 0 : 24
      n ||= min ? 0 : 60
      s ||= min ? 0 : 60
      self.where << "#{col} #{dir}= '%04d-%02d-%02d %02d:%02d:%02d'" %
        [y, m, d, h, n, s].map(&:to_i)
    end
  end
end
