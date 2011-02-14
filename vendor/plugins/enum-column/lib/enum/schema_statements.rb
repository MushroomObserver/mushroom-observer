module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      alias __type_to_sql_enum type_to_sql

      # # Add enumeration support for schema statement creation. This
      # # will have to be adapted for every adapter if the type requires
      # # anything by a list of allowed values. The overrides the standard
      # # type_to_sql method and chains back to the default. This could 
      # # be done on a per adapter basis, but is generalized here.
      # #
      # # will generate enum('a', 'b', 'c') for :limit => [:a, :b, :c]
      # def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
      #   if type == :enum
      #     native = native_database_types[type]
      #     column_type_sql = native[:name] || 'enum'
      #     
      #     column_type_sql << "(#{limit.map { |v| quote(v) }.join(',')})"
      #     column_type_sql          
      #   else
      #     # Edge rails fallback for Rails 1.1.6. We can remove the
      #     # rescue once everyone has upgraded to 1.2.
      #     begin
      #       __type_to_sql_enum(type, limit, precision, scale)
      #     rescue ArgumentError
      #       __type_to_sql_enum(type, limit)
      #     end
      #   end
      # end

      # There is a bug in the underlying rails 2.1.1 adapter.  This is a copy
      # of theirs with the enum stuff inserted from above and a fix.  This
      # bug only manifests in ruby 1.9.  Not sure why.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        if native = native_database_types[type]
          column_type_sql = native.is_a?(Hash) ? native[:name] : native

          # This is the key -- it is changing the column type in place
          # when modifying column_type_sql with the '<<' operator below.
          column_type_sql = column_type_sql.dup

          if type == :enum
            column_type_sql << "(#{limit.map { |v| quote(v) }.join(',')})"

          elsif type == :decimal # ignore limit, use precision and scale
            scale ||= native[:scale]

            if precision ||= native[:precision]
              if scale
                column_type_sql << "(#{precision},#{scale})"
              else
                column_type_sql << "(#{precision})"
              end
            elsif scale
              raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale if specified"
            end

          elsif limit ||= native.is_a?(Hash) && native[:limit]
            column_type_sql << "(#{limit})"
          end

          column_type_sql
        else
          type
        end
      end
    end
  end
end
