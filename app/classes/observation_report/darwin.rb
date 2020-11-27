# frozen_string_literal: true

module ObservationReport
  # Darwin Core Archive format.
  class Darwin < ObservationReport::ZipReport
    attr_accessor :csv

    def initialize(args)
      super(args)
      self.csv = DarwinCSV.new(args)
    end

    # generate CSV & meta.xml and bundle into a Zip
    def render
      self.content << ["meta.xml", File.open("#{::Rails.root}/public/dwca/meta.xml").read]
      self.content << ["observations.csv", self.csv.render]
      super
    end
  end
end
