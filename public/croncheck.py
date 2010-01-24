#!/usr/bin/python
import re, time

file_path = "/home/velosa/mushroomobserver.org/log/production.log"
pat = re.compile('Processing ObserverController#index \(for 65\.111\.164\.187 at (.+)\)')
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
  print "%s: %s, %s" % (time.mktime(p) - time.mktime(m), time.asctime(p), time.asctime(m))
  p = m
  pass
