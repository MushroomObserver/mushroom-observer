class Query::Base
  include Query::Initialize
  include Query::Title

  def parameter_declarations
    {
      join?:   [:string],
      tables?: [:string],
      where?:  [:string],
      group?:  :string,
      order?:  :string,
      by?:     :string,
      title?:  [:string],
    }
  end

  def initialize
  end
end
