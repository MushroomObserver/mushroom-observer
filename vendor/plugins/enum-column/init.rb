require 'enum/enum_adapter'
require 'enum/mysql_adapter' if defined? ActiveRecord::ConnectionAdapters::MysqlAdapter
require 'enum/postgresql_adapter' if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
require 'enum/sqlite3_adapter' if defined? ActiveRecord::ConnectionAdapters::SQLite3Adapter
require 'enum/schema_statements'
require 'enum/schema_definitions'
require 'enum/quoting'
require 'enum/validations'
require 'enum/active_record_helper'
