# frozen_string_literal: true

module Query
  module Modules
    # Helper methods for turning Query parameters into SQL conditions.
    module Conditions
      # Just because these three are used over and over again.
      def add_owner_and_time_stamp_conditions(table)
        add_time_condition("#{table}.created_at", params[:created_at])
        add_time_condition("#{table}.updated_at", params[:updated_at])
        add_id_condition("#{table}.user_id",
                         lookup_users_by_name(params[:users]))
      end

      def add_by_user_condition(table)
        return if params[:by_user].blank?

        user = find_cached_parameter_instance(User, :by_user)
        @title_tag = :query_title_by_user
        @title_args[:user] = user.legal_name
        where << "#{table}.user_id = '#{user.id}'"
      end

      def add_pattern_condition
        return if params[:pattern].blank?

        @title_tag = :query_title_pattern_search
        add_search_condition(search_fields, params[:pattern])
      end

      def add_boolean_condition(true_cond, false_cond, val, *)
        return if val.nil?

        @where << (val ? true_cond : false_cond)
        add_joins(*)
      end

      def add_exact_match_condition(col, vals, *)
        return if vals.blank?

        vals = [vals] unless vals.is_a?(Array)
        vals = vals.map { |v| escape(v.downcase) }
        @where << if vals.length == 1
                    "LOWER(#{col}) = #{vals.first}"
                  else
                    "LOWER(#{col}) IN (#{vals.join(", ")})"
                  end
        add_joins(*)
      end

      def add_search_condition(col, val, *)
        return if val.blank?

        search = google_parse(val)
        @where += google_conditions(search, col)
        add_joins(*)
      end

      def add_range_condition(col, val, *)
        return if val.blank?
        return if val[0].blank? && val[1].blank?

        min, max = val
        @where << "#{col} >= #{min}" if min.present?
        @where << "#{col} <= #{max}" if max.present?
        add_joins(*)
      end

      def add_string_enum_condition(col, vals, allowed, *)
        return if vals.empty?

        vals = vals.map(&:to_s) & allowed.map(&:to_s)
        return if vals.empty?

        @where << "#{col} IN ('#{vals.join("','")}')"
        add_joins(*)
      end

      def add_indexed_enum_condition(col, vals, allowed, *)
        return if vals.empty?

        vals = vals.filter_map { |v| allowed.index_of(v.to_sym) }
        return if vals.empty?

        @where << "#{col} IN (#{val.join(",")})"
        add_joins(*)
      end

      def add_ids_condition(table = model.table_name)
        return if params[:ids].blank?

        initialize_in_set_flavor(table)
      end

      # move this above when all in_set flavors converted
      def initialize_in_set_flavor(table = model.table_name)
        set = clean_id_set(params[:ids])
        @where << "#{table}.id IN (#{set})"
        self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"
      end

      def add_id_condition(col, ids, *)
        return if ids.nil?

        set = clean_id_set(ids)
        @where << "#{col} IN (#{set})"
        add_joins(*)
      end

      def add_not_id_condition(col, ids, *)
        return if ids.nil?

        set = clean_id_set(ids)
        @where << "#{col} NOT IN (#{set})"
        add_joins(*)
      end

      def add_where_condition(table, vals, *)
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
        add_joins(*)
      end

      def add_rank_condition(vals, *)
        return if vals.empty?

        min, max = vals
        max ||= min
        all_ranks = Name.all_ranks
        a = all_ranks.index(min) || 0
        b = all_ranks.index(max) || (all_ranks.length - 1)
        a, b = b, a if a > b
        ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
        @where << "names.`rank` IN (#{ranks.join(",")})"
        add_joins(*)
      end

      def add_image_size_condition(vals, *)
        return if vals.empty?

        min, max = vals
        sizes = Image::ALL_SIZES
        pixels = Image::ALL_SIZES_IN_PIXELS
        if min
          size = pixels[sizes.index(min)]
          @where << "images.width >= #{size} OR images.height >= #{size}"
        end
        if max
          size = pixels[sizes.index(max) + 1]
          @where << "images.width < #{size} AND images.height < #{size}"
        end
        add_joins(*)
      end

      def add_image_type_condition(vals, *)
        return if vals.empty?

        exts  = Image::ALL_EXTENSIONS.map(&:to_s)
        mimes = Image::ALL_CONTENT_TYPES.map(&:to_s) - [""]
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
        add_joins(*)
      end

      def add_with_notes_fields_condition(fields, *)
        return if fields.empty?

        conds = fields.map { |field| notes_field_presence_condition(field) }
        @where << conds.join(" OR ")
        add_joins(*)
      end

      def force_empty_results
        @where = ["FALSE"]
      end

      ##########################################################################

      private

      def notes_field_presence_condition(field)
        field = field.dup
        pat = if field.gsub!(/(["\\])/) { '\\\1' }
                "\":#{field}:\""
              else
                ":#{field}:"
              end
        "observations.notes like \"%#{pat}%\""
      end
    end
  end
end
