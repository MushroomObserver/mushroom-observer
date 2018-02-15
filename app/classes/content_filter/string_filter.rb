class ContentFilter
  class StringFilter < ContentFilter
    def type
      :string
    end

    def on?(val)
      !val.blank?
    end
  end
end
