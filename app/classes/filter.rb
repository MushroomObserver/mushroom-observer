module Filter
  def has_images
    {
      model:        Observation,
      checked_val:  "NOT NULL",           # value when checkbox checked
      off_val:      "off",                # filter is off
      on_vals:      ["NOT NULL", "NULL"], # allowed values when filter is on
      sql_cond:     "observations.thumb_image_id IS #{params[:has_images]}"
    }
  end

  def has_specimen
    {
      model:        Observation,
      checked_val:  "TRUE",
      off_val:      "off",
      on_vals:      ["TRUE", "FALSE"],
      sql_cond:     "observations.specimen IS #{params[:has_specimen]}"
   }
  end
end
