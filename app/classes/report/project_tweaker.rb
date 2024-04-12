# frozen_string_literal: true

module Report
  # Inserts the lat/long for hidden GPS coordinates
  # that the current user is allowed to see if
  # they are an admin for a project that another user trusts
  class ProjectTweaker
    def initialize
      @vals = {}
      ProjectLatLongs.new.vals.each do |row|
        @vals[row[0]] = [row[1], row[2]]
      end
    end

    def tweak(row)
      lat_lng = @vals[row[0]]
      if lat_lng
        row[2] = lat_lng[0]
        row[3] = lat_lng[1]
      end
      row
    end
  end
end
