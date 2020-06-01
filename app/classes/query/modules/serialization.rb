# frozen_string_literal: true

module Query
  module Modules
    # Turn a query into a string and vice versa.
    module Serialization
      def self.included(base)
        base.extend(ClassMethods)
      end

      def serialize
        hash = params.merge(
          model: model.to_s.to_sym,
          flavor: flavor
        )
        hash.keys.sort_by(&:to_s).map do |key|
          serialize_key_value(key, hash[key])
        end.join(";")
      end

      def serialize_key_value(key, val)
        key.to_s + "=" + serialize_value(val)
      end

      def serialize_value(val)
        case val
        when Array      then "@" + val.map { |v| serialize_value(v) }.join(",")
        when String     then "$" + serialize_string(val)
        when Symbol     then ":" + serialize_string(val.to_s)
        when Integer    then "#" + val.to_s
        when Float      then "#" + val.to_s
        when TrueClass  then "1"
        when FalseClass then "0"
        when NilClass   then "-"
        end
      end

      def serialize_string(val)
        # The "n" forces the Regexp to be in ascii 8 bit encoding = binary.
        String.new(val).force_encoding("binary").
          gsub(%r{[,;:#%&=/?\x00-\x1f\x7f-\xff]}n) do |char|
          format("%%%02.2X", char.ord)
        end
      end

      # Class methods.
      module ClassMethods
        def deserialize(str)
          params = deserialize_params(str)
          model  = params[:model]
          flavor = params[:flavor]
          params.delete(:model)
          params.delete(:flavor)
          Query.new(model, flavor, params)
        end

        def deserialize_params(str)
          params = {}
          str.split(";").each do |line|
            next if line !~ /^(\w+)=(.*)/

            key = Regexp.last_match(1)
            val = Regexp.last_match(2)
            params[key.to_sym] = deserialize_value(val)
          end
          params
        end

        def deserialize_value(val)
          val = val.sub(/^(.)/, "")
          case Regexp.last_match(1)
          when "@" then val.split(",").map { |v| deserialize_value(v) }
          when "$" then deserialize_string(val)
          when ":" then deserialize_string(val).to_sym
          when "#" then deserialize_number(val)
          when "1" then true
          when "0" then false
          when "-" then nil
          end
        end

        def deserialize_string(val)
          String.new(val).force_encoding("binary").gsub(/%(..)/) do |match|
            match[1..2].hex.chr("binary")
          end.force_encoding("UTF-8")
        end

        def deserialize_number(val)
          val.include?(".") ? val.to_f : val.to_i
        end
      end
    end
  end
end
