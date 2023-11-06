# frozen_string_literal: true

module Report
  class ProjectTweaker
    def initialize
      @vals = {}
      ProjectLatLongs.new.vals.each do |row|
        @vals[row[0]] = [row[1], row[2]]
      end
    end

    def tweak(row)
      lat_long = @vals[row[0]]
      if lat_long
        row[2] = lat_long[0]
        row[3] = lat_long[1]
      end
      row
    end
  end
end
