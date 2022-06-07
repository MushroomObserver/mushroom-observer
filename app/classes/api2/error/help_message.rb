# frozen_string_literal: true

class API2
  # API auto-discover help message.
  class HelpMessage < Error
    attr_accessor :params

    def initialize(params)
      super()
      self.params = params
      args.merge!(help: help_message)
    end

    def help_message
      if keys_for_patch.any?
        "query params: #{render_keys(keys_for_get)}; " \
          "update params: #{render_keys(keys_for_patch)}"
      else
        render_keys(all_keys)
      end
    end

    def render_keys(keys)
      keys.sort_by(&:to_s).map do |arg|
        params[arg].inspect
      end.join("; ")
    end

    def all_keys
      params.keys.reject { |k| params[k].deprecated? } - [
        :method, :action, :version, :api_key, :page, :detail, :format
      ]
    end

    def keys_for_get
      all_keys.reject { |k| params[k].set_parameter? }
    end

    def keys_for_patch
      all_keys.select { |k| params[k].set_parameter? }
    end
  end
end
