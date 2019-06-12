class Query::SequenceInSet < Query::SequenceBase
  def parameter_declarations
    super.merge(
      ids: [Sequence]
    )
  end

  def initialize_flavor
    add_id_condition("sequences.id", params[:ids])
    super
  end
end
