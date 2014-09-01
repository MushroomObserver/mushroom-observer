#!/usr/bin/env ruby
# 
# This is an example script I wrote for my personal notes.  Most of the script is
# concerned with parsing my notes.  Look for post_observation and post_image near
# the bottom of the file.  Notes files look like this:
#
# 20111019.not:
# 
#   [REG=USA, California, Ventura]
#   [LOC=Conejo Mountain]
#   [LAT=34.1898]
#   [LON=-118.9968]
#   [ALT=280]
#   
#   =115 Rinodina intermedia [A=O;B=soil;C=R;V=X] {on soil, K- C- KC-, submuriform spores}
#
################################################################################

require 'digest/md5'
require 'net/http'
require 'uri'
require 'cgi'
require 'rexml/document'

HOST = 'localhost.localdomain'
PORT = 80
KEY = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

# HOST = 'mushroomobserver.org'
# PORT = 80
# KEY = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

CODES = {
  'REG' => :region,
  'LOC' => :location,
  'HAB' => :habitat,
  'ASP' => :aspect,
  'SUB' => :substrate,
  'A'   => :aspect,
  'B'   => :substrate,
  'H'   => :habitat,
  'L'   => :location,
  'E'   => :altitude,
  'C'   => :confidence,
  'S'   => :source,
  'V'   => :voucher,
  'MO'  => :observation_id,
  'PH'  => :images,
  'PC'  => :primary_collector,
  'OC'  => :other_collectors,
  'LAT' => :latitude,
  'LON' => :longitude,
  'ALT' => :altitude,
  'GPS_FUDGE' => :ignore,
}

PARTS = {
  'THAL'   => 'THALLUS',
  'COR'    => 'CORTEX',
  'MED'    => 'MEDULLA',
  'APO'    => 'ASCOCARP',
  'ALG'    => 'PHOTOBIONT',
  'SPORE'  => 'SPORES',
  'SPORES' => 'SPORES',
}

LOCATION_MAP = {
}

################################################################################

class Observation
  attr_accessor :file
  attr_accessor :date
  attr_accessor :num
  attr_accessor :name
  attr_accessor :region
  attr_accessor :location
  attr_accessor :latitude
  attr_accessor :longitude
  attr_accessor :altitude
  attr_accessor :habitat
  attr_accessor :substrate
  attr_accessor :aspect
  attr_accessor :confidence
  attr_accessor :vote
  attr_accessor :source
  attr_accessor :voucher
  attr_accessor :specimen
  attr_accessor :observation_id
  attr_accessor :primary_collector
  attr_accessor :other_collectors
  attr_accessor :images
  attr_accessor :captions
  attr_accessor :notes
  attr_accessor :errors

  def initialize(file, num, &block)
    self.file = file
    self.date = file.sub(/[a-z]*$/,'')
    self.num  = num
    self.images = []
    self.captions = {}
    self.errors = []
    block.call(self) if block
  end

  # ----------------------------
  #  Data
  # ----------------------------

  def get_data
    get_notes
    get_captions
  end

  def get_notes
    file = "#{date}.not"
    raise "Missing file: #{file.inspect}" unless File.exist?(file)
    File.open(file, 'r:utf-8') do |fh|
      in_obs = false
      fh.each_line do |line|
        line.chomp!
        if line.match(/^=(\w+) /) and $1 == num
          parse_line(line)
          break
        elsif line.match(/(^|^[^=][^\[\]]*)\[([^\[\]]+)\]/)
          parse_args($2)
        end
      end
    end
  end

  def get_captions
    file = "../images/#{date}/captions.txt"
    File.open(file, 'r:utf-8') do |fh|
      fh.each_line do |line|
        line.chomp!
        if line.match(/^(\d+)(!?)\s+(\S(.*\S)?)/)
          num = $1.to_i
          vote = ($2 == '!') ? 3 : 2
          text = parse_caption($3)
          captions[num] = [vote, text]
        end
      end
    end
  end

  def expand_abbrev(code, str)
    file = "obv_codes.txt"
    File.open(file, 'r:utf-8') do |fh|
      abbr = ''
      in_codes = false
      fh.each_line do |line|
        line.chomp!
        if line.match(/^([A-Z]+)/) and $1 == code
          in_codes = true
        elsif in_codes
          if line.match(/^    ( *)(\w+)\s*(\S.*\S)/)
            abbr = abbr[0,$1.length] + $2
            if abbr == str
              return $3.sub(/[\!\*]$/,'').strip
            end
          else
            break
          end
        end
      end
    end
    return str
  end

  # ----------------------------
  #  Parsers
  # ----------------------------

  def parse_line(str)
    if not str.match(/^=(\w+)\s+([^\[\]]+\S)\s+\[([^\[\]]*)\](.*)/)
      raise "Line doesn't parse: #{str.inspect}"
    end
    name = $2
    args = $3
    notes = $4
    self.name = parse_name(name)
    self.notes = parse_notes(notes)
    parse_args(args)
  end

  def parse_args(str)
    str.gsub(/[,;]([A-Z_])/, "\n\\1").split("\n").each do |arg|
      if arg.match(/^([A-Z_]+)=(.*)/)
        var, val = $1, $2
        val.sub!(/^"(.*)"$/, '\1')
        val.sub!(/^'(.*)'$/, '\1')
        var2 = CODES[var]
        raise "Invalid code #{var.inspect} in #{str.inspect}" if !var2
        if var2 != :ignore
          send("#{var2}=", send("parse_#{var2}", val))
        end
      else
        raise "Invalid arg #{arg.inspect} in #{str.inspect}"
      end
    end
  end

  def parse_notes(str)
    notes = str.strip
    if notes.sub!(/^{/, '')
      notes = '*NOTES* ' + notes if not notes.match(/^[A-Z]{3}/)
    end
    notes.sub!(/\s*}\s*/, "\n\n")
    notes.sub!(/\n\((.*)\)/, "\n\\1")
    notes.gsub!(/(^|; *)([A-Z]{3,}) */) do |m|
      prefix, part = $1, $2
      part2 = PARTS[part]
      raise "Invalid part: #{part.inspect}" if !part2
      prefix + "*#{part2}* "
    end
    notes.gsub!(/(\d)x(\d)/, '\1 x \2')
    notes.gsub!(/(\d)um/, '\1 &micro;m')
    notes.gsub!(/<([^<>]*)>/, '_\1_')
    notes.strip!
    notes.sub!(/;$/, '.')
    return notes
  end

  def parse_caption(str)
    str.gsub!(/<([^<>]*)>/, '_\1_')
    str.gsub!(/\s+/, ' ')
    str.strip!
    return str
  end

  def parse_images(str)
    vals = []
    for val in str.split(',')
      if val.match(/-/)
        for v in ($`.to_i..$'.to_i)
          vals << v
        end
      else
        vals << val.to_i
      end
    end
    return vals
  end

  def parse_name(str)
    name = str.sub(/\?$/, '')
    if name.match(/^(\S+) (\S+) (\S+)/) and
       not %w(ssp. var. f.).include?($3)
      raise "Missing 'ssp.' or 'var.' in #{name.inspect}"
    end
    return name
  end

  def parse_region(val)
    return val
  end

  def parse_location(val)
    val = expand_abbrev('L', val)
    return val
  end

  def parse_habitat(val)
    val = expand_abbrev('H', val)
    val.gsub!(/<([^<>]*)>/, '_\1_')
    return val
  end

  def parse_aspect(val)
    val = expand_abbrev('A', val)
    val.gsub!(/<([^<>]*)>/, '_\1_')
    return val
  end

  def parse_substrate(val)
    val = expand_abbrev('B', val)
    val.gsub!(/<([^<>]*)>/, '_\1_')
    return val
  end

  def parse_latitude(val)
    return val
  end

  def parse_longitude(val)
    return val
  end

  def parse_altitude(val)
    val = expand_abbrev('E', val)
    return val
  end

  def parse_confidence(val)
    case val
    when 'A', 'S' ; 3
    when 'R', 'T' ; 2
    else          ; 1
    end
  end

  def parse_voucher(val)
    return true
  end

  def parse_source(val)
    val.split(/\s*,\s*/).map do |str|
      expand_abbrev('S', val)
    end.join(', ')
  end

  def parse_primary_collector(val)
    val.split(/\s*,\s*/).map do |str|
      expand_abbrev('S', val)
    end.join(', ')
  end

  def parse_other_collectors(val)
    val.split(/\s*,\s*/).map do |str|
      expand_abbrev('S', val)
    end.join(', ')
  end

  def parse_observation_id(val)
    raise "Invalid observation id #{val.inspect}" if not val.match(/^\d+$/)
    return val.to_i
  end

  # ----------------------------
  #  Format values
  # ----------------------------

  def format_notes
    str = @notes
    str = "\n\n" + str if not str.match(/^\*/)
    str = '*ASPECT* ' + @aspect + '; ' + str if @aspect
    str = '*SUBSTRATE* ' + @substrate + '; ' + str if @substrate
    str = '*HABITAT* ' + @habitat + '; ' + str if @habitat
    if @primary_collector or @other_collectors
      str = str.strip + "\n\n"
      if @primary_collectors
        str += '(collected by ' + @primary_collector
        str += ', with ' + @other_collectors if @other_collectors
        str += ')'
      elsif @other_collectors
        str += '(collected with ' + @other_collectors + ')'
      end
    end
    str.strip!
    str.sub!(/;$/, '.')
    return str
  end

  def format_location
    raise "Missing region!" if not @region
    raise "Missing location!" if not @location
    val = @region + ' Co., ' + @location
    return LOCATION_MAP[val] || val
  end

  def format_name
    name.sub(/ ssp\. /, ' subsp. ') rescue nil
  end

  # ----------------------------
  #  Edit data
  # ----------------------------

  def edit_data
    write_editor_file
    run_editor
    data = read_editor_file
    update_data(data)
  ensure
    if File.exist?(editor_file)
      File.unlink(editor_file)
    end
    if File.exist?(editor_file+'x')
      File.unlink(editor_file+'x')
    end
  end

  def run_editor
    if images != []
      image_files = images.map {|n| "../images/#{date}/#{n}.jpg"}
      system("eog #{image_files.join(' ')} &")
    end
    File.rename(editor_file, editor_file + 'x')
    system("screen vim -n -c ':0r #{editor_file}x' #{editor_file}")
    sleep 1 while `ps -ef`.include?(editor_file)
  end

  def write_editor_file
    File.open(editor_file, 'w:utf-8') do |fh|
      fh << format_editor_data(:date, date)
      fh << format_editor_data(:location, format_location)
      fh << format_editor_data(:latitude, latitude)
      fh << format_editor_data(:longitude, longitude)
      fh << format_editor_data(:altitude, altitude)
      fh << format_editor_data(:name, name)
      fh << format_editor_data(:vote, confidence)
      fh << format_editor_data(:specimen, voucher ? 'yes' : 'no')
      for img in images
        val = captions[img].join(' ').strip rescue '2'
        fh << format_editor_data(:"image_#{img}", val)
      end
      fh << format_editor_data(:notes, format_notes)
    end
  end

  def format_editor_data(var, val)
    val = val.to_s
    if val.include?("\n") or val.length > 90
      out = "#{var}:\n\n"
      for line in val.split("\n")
        for wrapped_line in wrap_line(line.strip)
          out += '  ' + wrapped_line + "\n"
        end
      end
      out += "\n"
    else
      out = "%-12.12s%s\n" % [ "#{var}:", val.strip ]
    end
    return out
  end

  def wrap_line(str)
    out = []
    str.gsub!(/\s+/, ' ')
    while str.length > 76
      if str.match(/^(.{1,77}) /)
        out << $1
        str = $'
      elsif str.match(/ /)
        out << $`
        str = $'
      else
        break
      end
    end
    out << str
    return out
  end

  def read_editor_file
    data = []
    if File.exist?(editor_file)
      File.open(editor_file, 'r:utf-8') do |fh|
        var = nil
        fh.each_line do |line|
          line.chomp!
          if line.match(/^(\w+):\s*$/)
            data << [$1.to_sym, '']
          elsif line.match(/^(\w+):\s*(\S(.*\S)?)\s*$/)
            data << [$1.to_sym, $2]
          else
            data[-1][1] += line.strip + "\n"
          end
        end
      end
      for var, val in data
        clean_space!(val)
      end
    end
    return data
  end

  def clean_space!(str)
    str.gsub!(/[ \t]+/, ' ')
    str.gsub!(/ \n|\n /, "\n")
    str.gsub!(/\n+/) do |x|
      x.length == 1 ? ' ' : "\n\n"
    end
    str.strip!
  end

  def update_data(data)
    self.date = nil
    self.location = nil
    self.latitude = nil
    self.longitude = nil
    self.altitude = nil
    self.name = nil
    self.vote = nil
    self.specimen = nil
    self.images = []
    for var, val in data
      if var.to_s.match(/^image_(\d+)$/)
        self.images << $1.to_i
        vote, text = val.to_s.strip.split(' ', 2)
        captions[$1.to_i] = [vote.to_i, text.to_s.strip]
      else
        send("#{var}=", val)
      end
    end
  end

  def editor_file
    ".upload_observation.#{$$}"
  end

  # ----------------------------
  #  Post data
  # ----------------------------

  def post_data
    post_observation
    for img in images
      post_image(img)
    end
  end

  def post_observation
    http = Net::HTTP.new(HOST, PORT)
    path = make_path('/api/observations',
      :api_key      => KEY,
      :date         => date,
      :location     => location,
      :notes        => notes,
      :latitude     => latitude,
      :longitude    => longitude,
      :altitude     => altitude,
      :has_specimen => specimen,
      :name         => format_name,
      :vote         => vote,
      :log          => 'no'
    )
    response = http.post(path, '')
    doc = REXML::Document.new(response.body)
    if errors = doc.root.elements['errors/error/details']
      raise "Error posting observation: #{errors.get_text}"
    end
    result = doc.root.elements['results/result']
    id = result.attribute('id').value.to_i
    self.observation_id = id
  end

  def post_image(img)
    http = Net::HTTP.new(HOST, PORT)
    path = make_path('/api/images',
      :api_key       => KEY,
      :date          => date,
      :notes         => captions[img][1],
      :vote          => captions[img][0],
      :original_name => "#{date}-#{img}.jpg",
      :observations  => observation_id
    )
    image = File.open("../images/#{date}/#{img}.jpg", 'rb') {|fh| fh.read}
    head = {
      'Content-Type' => 'image/jpeg',
      'Content-Length' => image.length.to_s,
      'Content-MD5' => Digest::MD5.hexdigest(image),
    }
    response = http.post(path, image, head)
    doc = REXML::Document.new(response.body)
    if errors = doc.root.elements['errors/error/details']
      self.errors << "Error posting image #{img}: #{errors.get_text}"
    end
  end

  def make_path(path, data)
    args = ''
    for var, val in data
      if val.to_s != ''
        args += args == '' ? '?' : '&'
        args += escape(var) + '=' + escape(val)
      end
    end
    return path + args
  end

  def escape(str)
    return CGI.escape(str.to_s)
  end
end

################################################################################

date, num = ARGV
raise "Missing or invalid date: #{date.inspect}" unless date.to_s.match(/^\d{8}[a-z]?$/)
raise "Missing or invalid num: #{num.inspect}" unless num.to_s.match(/^\d+[a-z]?$/)

begin
  obs = Observation.new(date, num)
  obs.get_data
  raise "Already posted!" if obs.observation_id
  obs.edit_data
  raise "Aborted operation!" if not obs.date.to_s.match(/\S/)
  obs.post_data
  $stdout.write(obs.observation_id)
  for err in obs.errors
    $stderr.puts err
  end
  exit 0
rescue => e
  $stderr.write(e.to_s)
  exit 1
end
