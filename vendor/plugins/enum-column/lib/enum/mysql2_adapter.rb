module ActiveRecord
  module ConnectionAdapters
    class Mysql2Adapter
      alias __native_database_types_enum native_database_types
      
      def native_database_types #:nodoc
        types = __native_database_types_enum
        types[:enum] = { :name => "enum" }
        types
      end

      def columns(table_name, name = nil)#:nodoc:
        sql = "SHOW FIELDS FROM #{table_name}"
        columns = []
        result = execute(sql, :skip_logging)
        result.each(:symbolize_keys => true, :as => :hash) { |field|
          columns << Mysql2ColumnWithEnum.new(field[:Field], field[:Default], field[:Type], field[:Null] == "YES")
        }
        columns
      end
    end
    
    class Mysql2ColumnWithEnum < Mysql2Column
      include ActiveRecordEnumerations::Column
      
      def initialize(name, default, sql_type = nil, null = true)
        if sql_type =~ /^enum/i
          values = sql_type.sub(/^enum\('([^)]+)'\)/i, '\1').split("','").map { |v| v.intern }
          default = default.intern if default and !default.empty?
        end
        super(name, default, sql_type, null, values)
      end
    end
  end
end
