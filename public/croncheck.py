#!/usr/bin/python
import re, time

file_path = "/Users/velosa/ruby/mushroom_sightings/trunk/log/development.log"
pat = re.compile('Processing ObserverController#index \(for 127\.0\.0\.1 at (.+)\)')
time_format = '%Y-%m-%d %H:%M:%S'
f = open(file_path)
line = f.readline()
matches = []
while line:
  m = pat.match(line)
  if m:
    matches.append(time.strptime(m.group(1), time_format))
    pass
  line = f.readline()
  pass

matches.reverse()
p = time.localtime()
for m in matches:
  print time.mktime(p) - time.mktime(m)
  p = m
  pass
