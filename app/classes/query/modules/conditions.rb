# Helper methods for turning Query parameters into SQL conditions.
#
# rubocop:disable Metrics/ModuleLength
module Query::Modules::Conditions
  # rubocop:disable Metrics/AbcSize

  # Just because these three are used over and over again.
  def add_owner_and_time_stamp_conditions(table)
    add_time_condition("#{table}.created_at", params[:created_at])
    add_time_condition("#{table}.updated_at", params[:updated_at])
    add_id_condition("#{table}.user_id", lookup_users_by_name(params[:users]))
  end

  def add_boolean_condition(true_cond, false_cond, val, *joins)
    return if val.nil?

    @where << (val ? true_cond : false_cond)
    add_joins(*joins)
  end

  def add_exact_match_condition(col, vals, *joins)
    return if vals.blank?

    vals = [vals] unless vals.is_a?(Array)
    vals = vals.map { |v| escape(v.downcase) }
    @where << if vals.length == 1
                "LOWER(#{col}) = #{vals.first}"
              else
                "LOWER(#{col}) IN (#{vals.join(", ")})"
              end
    add_joins(*joins)
  end

  def add_search_condition(col, val, *joins)
    return if val.blank?

    search = google_parse(val)
    @where += google_conditions(search, col)
    add_joins(*joins)
  end

  def add_range_condition(col, val, *joins)
    return if val.blank?
    return if val[0].blank? && val[1].blank?

    min, max = val
    @where << "#{col} >= #{min}" if min.present?
    @where << "#{col} <= #{max}" if max.present?
    add_joins(*joins)
  end

  def do_string_enum_condition(col, vals, allowed, *joins)
    return if vals.empty?

    vals = vals.map(&:to_s) & allowed.map(&:to_s)
    return if vals.empty?

    @where << "#{col} IN ('#{vals.join("','")}')"
    add_joins(*joins)
  end

  def do_indexed_enum_condition(col, vals, allowed, *joins)
    return if vals.empty?

    vals = vals.map { |v| allowed.index_of(v.to_sym) }.reject(&:nil?)
    return if vals.empty?

    @where << "#{col} IN (#{val.join(",")})"
    add_joins(*joins)
  end

  def add_id_condition(col, ids, *joins)
    return if ids.empty?

    set = clean_id_set(ids)
    @where << "#{col} IN (#{set})"
    add_joins(*joins)
  end

  def lookup_external_sites_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      ExternalSite.where(name: name)
    end
  end

  def lookup_herbaria_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      Herbarium.where(name: name)
    end
  end

  def lookup_herbarium_records_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      HerbariumRecord.where(herbarium_label: name)
    end
  end

  def lookup_locations_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      pattern = clean_pattern(Location.clean_name(name))
      Location.where("name LIKE ?", "%#{pattern}%")
    end
  end

  def lookup_projects_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      Project.where(title: name)
    end
  end

  def lookup_species_lists_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      SpeciesList.where(title: name)
    end
  end

  def lookup_users_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      User.where(login: name.sub(/ *<.*>/, ""))
    end
  end

  def lookup_objects_by_name(vals)
    return unless vals

    vals.map do |val|
      if /^\d+$/.match?(val.to_s)
        val
      else
        yield(val).map(&:id)
      end
    end.flatten.uniq.reject(&:nil?)
  end

  def lookup_names_by_name(vals, filter = nil)
    return unless vals

    vals.map do |val|
      if /^\d+$/.match?(val.to_s)
        if filter
          Name.safe_find(val).send(filter).map(&:id)
        else
          val
        end
      elsif filter
        find_matching_names(val).map(&:send, filter).map(&:id)
      else
        find_matching_names(val).map(&:id)
      end
    end.flatten.uniq.reject(&:nil?)
  end

  def find_matching_names(name)
    parse = Name.parse_name(name)
    name2 = parse ? parse.search_name : Name.clean_incoming_string(name)
    matches = Name.where(search_name: name2)
    matches = Name.where(text_name: name2) if matches.empty?
    matches
  end

  def add_location_condition(table, vals, *joins)
    return if vals.empty?

    loc_col   = "#{table}.location_id"
    where_col = "#{table}.where"
    ids       = clean_id_set(lookup_locations_by_name(vals))
    cond      = "#{loc_col} IN (#{ids})"
    vals.each do |val|
      if /\D/.match?(val)
        pattern = clean_pattern(val)
        cond += " OR #{where_col} LIKE '%#{pattern}%'"
      end
    end
    @where << cond
    add_joins(*joins)
  end

  def add_bounding_box_conditions_for_locations
    return unless params[:north] && params[:south] &&
                  params[:east] && params[:west]

    _, cond2 = bounding_box_conditions
    @where += cond2
  end

  def add_bounding_box_conditions_for_observations
    return unless params[:north] && params[:south] &&
                  params[:east] && params[:west]

    cond1, cond2 = bounding_box_conditions
    cond0 = lat_long_plausible
    cond1 = cond1.join(" AND ")
    cond2 = cond2.join(" AND ")
    @where << "IF(locations.id IS NULL OR #{cond0}, #{cond1}, #{cond2})"
    add_join_to_locations
  end

  def lat_long_plausible
    # Condition which returns true if the observation's lat/long is plausible.
    # (should be identical to BoxMethods.lat_long_close?)
    %(
      observations.lat >= locations.south*1.2 - locations.north*0.2 AND
      observations.lat <= locations.north*1.2 - locations.south*0.2 AND
      if(locations.west <= locations.east,
        observations.long >= locations.west*1.2 - locations.east*0.2 AND
        observations.long <= locations.east*1.2 - locations.west*0.2,
        observations.long >= locations.west*0.8 + locations.east*0.2 + 72 OR
        observations.long <= locations.east*0.8 + locations.west*0.2 - 72
      )
    )
  end

  def bounding_box_conditions
    n, s, e, w = params.values_at(:north, :south, :east, :west)
    if w < e
      bounding_box_normal(n, s, e, w)
    else
      bounding_box_straddling_date_line(n, s, e, w)
  end

  def bounding_box_normal(n, s, e, w)
    [
      # point location inside target box
      "observations.lat >= #{s}",
      "observations.lat <= #{n}",
      "observations.long >= #{w}",
      "observations.long <= #{e}"
    ], [
      # box entirely within target box
      "locations.south >= #{s}",
      "locations.north <= #{n}",
      "locations.west >= #{w}",
      "locations.east <= #{e}",
      "locations.west <= locations.east"
    ]
  end

  def bounding_box_straddling_date_line(n, s, e, w)
    [
      # point location inside target box
      "observations.lat >= #{s}",
      "observations.lat <= #{n}",
      "(observations.long >= #{w} OR observations.long <= #{e})"
    ], [
      # box entirely within target box
      "locations.south >= #{s}",
      "locations.north <= #{n}",
      "locations.west >= #{w}",
      "locations.east <= #{e}",
      "locations.west > locations.east"
    ]
  end

  def add_rank_condition(vals, *joins)
    return if vals.empty?

    min, max = vals
    max ||= min
    all_ranks = Name.all_ranks
    a = all_ranks.index(min) || 0
    b = all_ranks.index(max) || (all_ranks.length - 1)
    a, b = b, a if a > b
    ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
    @where << "names.rank IN (#{ranks.join(",")})"
    add_joins(*joins)
  end

  def add_image_size_condition(vals, *joins)
    return if vals.empty?

    min, max = vals
    sizes  = Image.all_sizes
    pixels = Image.all_sizes_in_pixels
    if min
      size = pixels[sizes.index(min)]
      @where << "#images.width >= #{size} OR images.height >= #{size}"
    end
    if max
      size = pixels[sizes.index(max) + 1]
      @where << "images.width < #{size} AND images.height < #{size}"
    end
    add_joins(*joins)
  end

  def add_image_type_condition(vals, *joins)
    return if vals.empty?

    exts  = Image.all_extensions.map(&:to_s)
    mimes = Image.all_content_types.map(&:to_s) - [""]
    types = vals & exts
    return if vals.empty?

    other = types.include?("raw")
    types -= ["raw"]
    types = types.map { |x| mimes[exts.index(x)] }
    str1 = "images.content_type IN ('#{types.join("','")}')"
    str2 = "images.content_type NOT IN ('#{mimes.join("','")}')"
    @where << if types.empty?
                str2
              elsif other
                "#{str1} OR #{str2}"
              else
                str1
              end
  end

  def add_date_condition(col, vals, *joins)
    return if vals.empty?

    # Ugh, special case for search by month/day where range of months wraps
    # around from December to January.
    if vals[0].to_s.match(/^\d\d-\d\d$/) &&
       vals[1].to_s.match(/^\d\d-\d\d$/) &&
       vals[0].to_s > vals[1].to_s
      m1, d1 = vals[0].to_s.split("-")
      m2, d2 = vals[1].to_s.split("-")
      @where << "MONTH(#{col}) > #{m1} OR " \
                "MONTH(#{col}) < #{m2} OR " \
                "(MONTH(#{col}) = #{m1} AND DAY(#{col}) >= #{d1}) OR " \
                "(MONTH(#{col}) = #{m2} AND DAY(#{col}) <= #{d2})"
    else
      add_half_date_condition(true, col, vals[0])
      add_half_date_condition(false, col, vals[1])
    end
    add_joins(*joins)
  end

  def add_half_date_condition(min, col, val)
    dir = min ? ">" : "<"
    if /^\d\d\d\d/.match?(val.to_s)
      y, m, d = val.split("-")
      @where << sprintf("#{col} #{dir}= '%04d-%02d-%02d'",
                        y.to_i,
                        (m || (min ? 1 : 12)).to_i,
                        (d || (min ? 1 : 31)).to_i)
    elsif /-/.match?(val.to_s)
      m, d = val.split("-")
      @where << "MONTH(#{col}) #{dir} #{m} OR " \
                "(MONTH(#{col}) = #{m} AND " \
                "DAY(#{col}) #{dir}= #{d})"
    elsif val.present?
      @where << "MONTH(#{col}) #{dir}= #{val}"
    end
  end

  def add_time_condition(col, vals, *joins)
    return unless vals

    add_half_time_condition(true, col, vals[0])
    add_half_time_condition(false, col, vals[1])
    add_joins(*joins)
  end

  def add_half_time_condition(min, col, val)
    return if val.blank?

    y, m, d, h, n, s = val.split("-")
    @where << sprintf(
      "#{col} %s= '%04d-%02d-%02d %02d:%02d:%02d'",
      min ? ">" : "<",
      y.to_i,
      (m || (min ? 1 : 12)).to_i,
      (d || (min ? 1 : 31)).to_i,
      (h || (min ? 0 : 24)).to_i,
      (n || (min ? 0 : 60)).to_i,
      (s || (min ? 0 : 60)).to_i
    )
  end

  def add_has_notes_fields_condition(fields, *joins)
    return if fields.empty?

    conds = fields.map { |field| notes_field_presence_condition(field) }
    @where << conds.join(" OR ")
    add_joins(*joins)
  end

  def notes_field_presence_condition(field)
    field = field.clone
    pat = if field.gsub!(/(["\\])/) { |m| '\\\1' }
            "\":#{key}:\""
          else
            ":#{key}:"
          end
    "observations.notes like \"%#{pat}%\""
  end
end
