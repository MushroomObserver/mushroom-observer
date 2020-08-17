# frozen_string_literal: true

module Query
  module Modules
    # validation of Query parameters
    module Validation
      attr_accessor :params
      attr_accessor :params_cache

      def required_parameters
        keys = parameter_declarations.keys
        keys.select! { |x| x.to_s[-1] == "?" }
        keys.sort_by(&:to_s)
      end

      def validate_params
        old_args = @params.dup
        new_args = {}
        parameter_declarations.each do |arg, arg_type|
          validate_param(old_args, new_args, arg, arg_type)
        end
        check_for_unexpected_params(old_args)
        @params = new_args
      end

      def validate_param(old_args, new_args, arg, arg_type)
        arg_sym = arg.to_s.sub(/\?$/, "").to_sym
        optional = (arg != arg_sym)
        begin
          val = pop_param_value(old_args, arg_sym)
          val = validate_value(arg_type, arg_sym, val) if val.present?
          if !val.nil?
            new_args[arg_sym] = val
          elsif !optional
            raise(
              "Missing :#{arg_sym} parameter for #{model} :#{flavor} query."
            )
          else
            new_args[arg_sym] = nil
          end
        rescue MissingValue
          unless optional
            raise(
              "Missing :#{arg_sym} parameter for #{model} :#{flavor} query."
            )
          end
        end
      end

      class MissingValue < RuntimeError; end

      def pop_param_value(args, arg)
        if args.key?(arg)
          val = args[arg]
        elsif args.key?(arg.to_s)
          val = args[arg.to_s]
        else
          raise(MissingValue.new)
        end
        args.delete(arg)
        args.delete(arg.to_s)
        val
      end

      def check_for_unexpected_params(old_args)
        return if old_args.keys.empty?

        str = old_args.keys.map(&:to_s).join("', '")
        raise("Unexpected parameter(s) '#{str}' for #{model} :#{flavor} query.")
      end

      def array_validate(arg, val, arg_type)
        if val.is_a?(Array)
          val[0, MO.query_max_array].map do |val2|
            scalar_validate(arg, val2, arg_type)
          end
        elsif val.is_a?(API::OrderedRange)
          [scalar_validate(arg, val.begin, arg_type),
           scalar_validate(arg, val.end, arg_type)]
        else
          [scalar_validate(arg, val, arg_type)]
        end
      end

      def scalar_validate(arg, val, arg_type)
        if arg_type.is_a?(Symbol)
          send("validate_#{arg_type}", arg, val)
        elsif arg_type.is_a?(Class) &&
              arg_type.respond_to?(:descends_from_active_record?)
          validate_id(arg, val, arg_type)
        elsif arg_type.is_a?(Hash)
          validate_enum(arg, val, arg_type)
        else
          raise("Invalid declaration of :#{arg} for #{model} :#{flavor} "\
                "query! (invalid type: #{arg_type.class.name})")
        end
      end

      def validate_enum(arg, val, hash)
        if hash.keys.length != 1
          raise("Invalid enum declaration for :#{arg} for #{model} :#{flavor} "\
                "query! (wrong number of keys in hash)")
        end

        arg_type = hash.keys.first
        set = hash.values.first
        unless set.is_a?(Array)
          raise("Invalid enum declaration for :#{arg} for #{model} :#{flavor} "\
                "query! (expected value to be an array of allowed values)")
        end

        val2 = scalar_validate(arg, val, arg_type)
        if (arg_type == :string) && set.include?(val2.to_sym)
          val2 = val2.to_sym
        elsif !set.include?(val2)
          raise("Value for :#{arg} should be one of the following: "\
                "#{set.inspect}.")
        end
        val2
      end

      def validate_boolean(arg, val)
        case val
        # Disable cop because we do mean to symbols with boolean names
        # rubocop:disable Lint/BooleanSymbol
        when :true, :yes, :on, "true", "yes", "on", "1", 1, true
          true
        when :false, :no, :off, "false", "no", "off", "0", 0, false, nil
          false
        # rubocop:enable Lint/BooleanSymbol
        else
          raise("Value for :#{arg} should be boolean, got: #{val.inspect}")
        end
      end

      def validate_integer(arg, val)
        if val.is_a?(Integer) ||
           val.is_a?(String) && val.match(/^-?\d+$/)
          val.to_i
        elsif val.blank?
          nil
        else
          raise("Value for :#{arg} should be an integer, got: #{val.inspect}")
        end
      end

      def validate_float(arg, val)
        if val.is_a?(Integer) ||
           val.is_a?(Float) ||
           (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
          val.to_f
        else
          raise("Value for :#{arg} should be a float, got: #{val.inspect}")
        end
      end

      def validate_string(arg, val)
        if val.is_a?(Integer) ||
           val.is_a?(Float) ||
           val.is_a?(String) ||
           val.is_a?(Symbol)
          val.to_s
        else
          raise("Value for :#{arg} should be a string or symbol, "\
                "got a #{val.class}: #{val.inspect}")
        end
      end

      def validate_id(arg, val, type = ActiveRecord::Base)
        if val.is_a?(type)
          unless val.id
            raise("Value for :#{arg} is an unsaved #{type} instance.")
          end

          # Cache the instance for later use, in case we both instantiate and
          # execute query in the same action.
          @params_cache ||= {}
          @params_cache[arg] = val
          val.id
        elsif could_be_record_id?(val)
          val.to_i
        else
          raise("Value for :#{arg} should be id or an #{type} instance, "\
                "got: #{val.inspect}")
        end
      end

      def validate_name(arg, val)
        if val.is_a?(Name)
          raise("Value for :#{arg} is an unsaved Name instance.") unless val.id

          @params_cache ||= {}
          @params_cache[arg] = val
          val.id
        elsif val.is_a?(String)
          val
        elsif val.is_a?(Integer)
          val
        else
          raise("Value for :#{arg} should be a Name, String or Integer, " \
                "got: #{val.class}")
        end
      end

      def validate_date(arg, val)
        if val.acts_like?(:date)
          format("%04d-%02d-%02d", val.year, val.mon, val.day)
        elsif /^\d\d\d\d(-\d\d?){0,2}$/i.match?(val.to_s)
          val
        elsif /^\d\d?(-\d\d?)?$/i.match?(val.to_s)
          val
        elsif val.blank? || val.to_s == "0"
          nil
        else
          raise("Value for :#{arg} should be a date (YYYY-MM-DD or MM-DD), " \
                "got: #{val.inspect}")
        end
      end

      def validate_time(arg, val)
        if val.acts_like?(:time)
          val = val.utc
          format("%04d-%02d-%02d-%02d-%02d-%02d",
                 val.year, val.mon, val.day, val.hour, val.min, val.sec)
        elsif /^\d\d\d\d(-\d\d?){0,5}$/i.match?(val.to_s)
          val
        elsif val.blank? || val.to_s == "0"
          nil
        else
          raise(
            "Value for :#{arg} should be a UTC time (YYYY-MM-DD-HH-MM-SS), " \
            "got: #{val.inspect}"
          )
        end
      end

      def validate_query(arg, val)
        if val.is_a?(Query::Base)
          val.record.id
        elsif val.is_a?(Integer)
          val
        else
          raise(
            "Value for :#{arg} should be a Query class, got: #{val.inspect}"
          )
        end
      end

      def find_cached_parameter_instance(model, arg)
        @params_cache ||= {}
        @params_cache[arg] ||= model.find(params[arg])
      end

      def get_cached_parameter_instance(arg)
        @params_cache ||= {}
        @params_cache[arg]
      end

      # ------------------------------------------------------------------------

      private

      def validate_value(arg_type, arg_sym, val)
        if arg_type.is_a?(Array)
          array_validate(arg_sym, val, arg_type.first)
        else
          scalar_validate(arg_sym, val, arg_type)
        end
      end

      def could_be_record_id?(val)
        val.is_a?(Integer) ||
          val.is_a?(String) && val.match(/^[1-9]\d*$/) ||
          # (blasted admin user has id = 0!)
          val.is_a?(String) && (val == "0") && (arg == :user)
      end
    end
  end
end
