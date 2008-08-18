module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      alias __native_database_types_enum native_database_types
      
      def native_database_types #:nodoc
        types = __native_database_types_enum
        types[:enum] = { :name => "varchar(32)" }
        types
      end

      def columns(table_name, name = nil)#:nodoc:
        constraints = { }
        @connection.execute "SELECT sql FROM sqlite_master WHERE name = '#{table_name}'" do |row|
          sql = row[0]
          sql.scan(/, \"(\w+)\" varchar\(32\) CHECK\(\"\w+\" in \(([^\)]+)\)/i) do |column, constraint|
            constraints[column] = constraint
          end
        end
        table_structure(table_name).map do |field|
          name = field['name']
          type = field['type']
          if (const = constraints[name])
            type = "enum(#{const.strip})"
          end
          SQLite3ColumnWithEnum.new(name, field['dflt_value'], type, field['notnull'] == "0")
        end
      end

      def add_column_options!(sql, options)
        unless sql =~ /\(32\)\('[^']+'/
          super(sql, options)
        else
          sql.gsub!(/("[^"]+")([^3]+32\))(.+)/, '\1\2 CHECK(\1 in \3)')
          super(sql, options)
        end
      end
    end
    
    class SQLite3ColumnWithEnum < SQLiteColumn
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
