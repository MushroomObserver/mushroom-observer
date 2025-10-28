# frozen_string_literal: true

# Used to ensure all keys to the hash use underscores
# rather than spaces and that the keys are case insensitive
# for setting, but the key used is the first one that gets
# assigns.
#
# See the Observation cache for the primary use case
class NormalizedHash
  extend Forwardable
  def_delegators :@hash, :[], :keys, :values, :each, :each_pair, :map, :select,
                 :reject, :empty?, :size, :length, :to_s, :inspect, :except,
                 :key?, :has_key?, :include?, :fetch, :dig, :merge, :delete,
                 :clear, :each_key, :each_value, :transform_values, :==,
                 :value_merge!, :compact_blank!, :each_with_object, :to_unsafe_h

  def initialize(hash = {})
    @hash = hash.is_a?(Hash) ? hash : {}
  end

  def []=(key, value)
    normalized_key = key.to_s.gsub(' ', '_')
    comparison_key = normalized_key.downcase
    
    existing_key = @hash.keys.find do |existing|
      existing.to_s.downcase == comparison_key
    end
    
    if existing_key
      @hash[existing_key] = value
    else
      @hash[normalized_key.to_sym] = value
    end
  end
  
  # Return the underlying hash for serialization
  def to_h
    @hash
  end
  
  alias_method :to_hash, :to_h
end
