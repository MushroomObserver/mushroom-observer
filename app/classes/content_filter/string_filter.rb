class ContentFilter
  class StringFilter < ContentFilter
    def type
      :string
    end

    def on?(val)
      val.present?
    end
  end
end
