#!/usr/bin/env ruby

require 'extractor/nqa'
require 'cgi'

cgi = CGI.new

if cgi.params.include? 'secs'
  secs = cgi.params['secs'][0].to_i
else
  secs = 86400
end

ex = NQAExtractor.new
hosts = ex.all_hosts_probes

puts "Content-type: text/html\n\n"
puts "<!DOCTYPE html>"
puts "<html><head></head><body>"
hosts.each do |hid, hname, pid, pname|
  link = "nqaplot.cgi?id=#{hid}:#{pid}&secs=#{secs}&title=NQA+results+for+#{hname}+#{pname}"
  puts "<a href='#{link}'><img src='#{link}' /></a>"
end
puts "</body></html>"

