# frozen_string_literal: true

namespace :visual_model do
  desc "Update a VisualModel from a list of updates"
  task(update: :environment) do
    Rails.logger = Logger.new($stdout)
    model_name = ENV.fetch("MODEL_NAME", nil)
    update_list = ENV.fetch("UPDATE_LIST", nil)
    unless model_name && update_list && File.file?(update_list)
      report_update_usage
    end
    build_from_file(model_name, update_list)
  end

  desc "Export VisualGroup"
  task(export: :environment) do
    Rails.logger = Logger.new($stdout)
    model_name = ENV.fetch("MODEL_NAME", nil)
    group_names = ENV.fetch("GROUP_NAMES", nil)
    output_file = ENV.fetch("OUTPUT_FILE", nil)
    report_export_usage unless model_name && output_file
    export_model(model_name, group_names, output_file)
  end
end

# visual_model:update support

def report_update_usage
  Rails.logger.error(
    "\nThis task expects the MODEL_NAME and UPDATE_LIST to be given\n" \
    "through environment variables, and for the value of UPDATE_LIST\n" \
    "to be an existing file.\n" \
    "\nExample usage:\n" \
    "MODEL_NAME=MyModel UPDATE_LIST=./update_list rails visual_model:update\n" \
    "\nExample lines from UPDATE_LIST:\n" \
    "Aseroe rubra # Add all images for a species to visual group\n" \
    "1234 Lepista nuda # Include specific image\n" \
    "-2345 Verpa conica # Exclude specific image\n" \
    "3456 # Move image to current name\n" \
    "- Bad name # Delete a visual group\n" \
    "= Clitocybe nuda, Lepista nuda # Merge groups into first group\n" \
  )
  exit
end

def build_from_file(model_name, update_list)
  model = VisualModel.find_or_create_by(name: model_name)
  if model.save
    File.open(update_list) do |file|
      file.readlines.each do |line|
        process_line(model, line)
      end
    end
  end
  return unless model.errors.count.positive?

  Rails.logger.error("VisualModel errors:")
  Rails.logger.error(model.errors.full_messages)
end

def process_line(model, raw_cmd)
  cmd = raw_cmd[/^[^#]*/].strip # Remove any comment and extra whitespace
  return if cmd == ""

  action, data = parse_cmd(cmd)
  print("parse_cmd: #{action}, #{data}\n")
  if action == "delete"
    delete_visual_group(model, data)
  elsif action == "merge"
    merge_visual_groups(model, data)
  elsif action.nil?
    add_visual_group(model, data)
  else
    adjust_image(model, action, data)
  end
end

def parse_cmd(cmd)
  first_space = cmd.index(" ")
  return process_simple_cmd(cmd) if first_space.nil?

  first_token = cmd[..first_space - 1]
  rest = cmd[first_space + 1..]
  return ["delete", rest] if first_token == "-"
  return ["merge", rest] if first_token == "="

  id = begin
         Integer(first_token)
       rescue StandardError
         nil
       end
  return [nil, cmd] if id.nil?

  [id, rest]
end

def process_simple_cmd(cmd)
  id = Integer(cmd)
  img = Image.find_by(id: id)
  return [nil, cmd] unless img

  obs = img.observations.first
  return [id, cmd] unless obs

  [id, obs.name.text_name]
rescue StandardError
  [nil, cmd]
end

def delete_visual_group(model, name)
  Rails.logger.info { "Deleting VisualGroup for '#{name}'" }
  VisualGroup.where(visual_model: model, name: name).each(&:destroy)
end

def merge_visual_groups(model, groups)
  Rails.logger.info { "Merging VisualGroups '#{groups}'" }
  names = groups.split(",").map(&:strip)
  return if names == []

  target_group = VisualGroup.find_or_create_by(visual_model: model,
                                               name: names[0])
  return unless target_group

  names.each do |name|
    VisualGroup.where(visual_model: model, name: name).each do |group|
      next if target_group == group

      Rails.logger.info { "Merging '#{name}'" }
      target_group.merge(group)
    end
  end
end

def add_visual_group(model, name)
  Rails.logger.info { "Adding VisualGroup for '#{name}'" }
  errors = create_visual_group(model, name)
  Rails.logger.error(errors.full_messages) if errors
end

def create_visual_group(model, name)
  group = VisualGroup.new(visual_model: model, name: name)
  if group.save
    group.add_initial_images
    nil
  else
    group.errors
  end
end

def adjust_image(model, raw_id, name)
  group = VisualGroup.find_or_create_by(visual_model: model, name: name)
  vgi = VisualGroupImage.joins(:visual_group).find_by(
    image_id: raw_id.abs,
    visual_groups: { visual_model_id: model.id }
  )
  if vgi.nil?
    add_image(group, raw_id)
  else
    move_image(vgi, group, raw_id)
  end
end

def add_image(group, raw_id)
  id = raw_id.abs
  Rails.logger.info { "Adding image #{id} to #{group.name}" }
  VisualGroupImage.create(visual_group: group,
                          image_id: id,
                          included: raw_id.positive?)
end

def move_image(vgi, group, raw_id)
  old_name = vgi.visual_group.name
  Rails.logger.info do
    "Moving image #{raw_id.abs} from #{old_name} to #{group.name}"
  end
  vgi.visual_group = group
  vgi.included = raw_id.positive?
  vgi.save
end

# visual_model:export support

def report_export_usage
  Rails.logger.error(
    "\nThis task expects the MODEL_NAME and the OUTPUT_FILE to be given\n  " \
    "through environment variables.  GROUP_NAMES can be given to limit\n  " \
    "the export.\n" \
    "\nExample usage:\n" \
    "MODEL_NAME=MyModel OUTPUT_FILE=./output_list " \
    "GROUP_NAMES='Microscopy, Text' rails visual_model:export"
  )
  exit
end

def export_model(model_name, group_names, output_file)
  model = VisualModel.find_by(name: model_name)
  if model
    File.open(output_file, "w") do |file|
      if group_names.nil?
        export_all_groups(model, file)
      else
        export_group_names(model, group_names, file)
      end
    end
  else
    Rails.logger.error("Unable to find the VisualModel #{model_name}")
  end
end

def export_all_groups(model, file)
  model.visual_groups.each do |group|
    export_group(group, file)
  end
end

def export_group_names(model, group_names, file)
  group_names.split(",").each do |name|
    name = name.strip
    next if name == ""

    group = model.visual_groups.find_by(name: name)
    if group
      export_group(group, file)
    else
      Rails.logger.error("Unable to find the VisualGroup #{name}")
    end
  end
end

def export_group(group, file)
  group.visual_group_images.each do |vgi|
    image_ref = vgi.included ? vgi.image_id : -vgi.image_id
    file.write("#{image_ref} #{group.name}\n")
  end
end
