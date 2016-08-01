class Query::RssLog < Query::Base
  def model
    RssLog
  end

  def parameter_declarations
    super.merge(
      updated_at?: [:time],
      type?:       :string
    )
  end

  def initialize_flavor
    initialize_model_do_time(:updated_at)
    add_rss_log_type_condition(params[:type])
    super
  end

  def default_order
    "updated_at"
  end

  def add_rss_log_type_condition(arg)
    types = (arg || "all").to_s.split
    unless types.include?("all")
      types &= RssLog.all_types
      if types.empty?
        self.where << "FALSE"
      else
        self.where << types.map do |type|
          "rss_logs.#{type}_id IS NOT NULL"
        end.join(" OR ")
      end
    end
  end
end
