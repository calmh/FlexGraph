#!/usr/bin/env ruby

require 'lib/gnuplotter'
require 'extractor/rtg'
require 'cgi'

puts "Content-type: text/html\n\n"
puts <<HEADER
<!DOCTYPE html>
<html>
<head>
<style type='text/css'>
div.interface {
  float: left;
}
div.router {
  float: left;
  padding: 2px;
  width: 12em;
}
</style>
</head>
<body>
HEADER

cgi = CGI.new
rid = cgi.params['rid'][0].to_i
iid = cgi.params['iid'][0].to_i
old = cgi.params['old'][0].to_i

ex = RTGExtractor.new

if !iid.nil? && iid != 0 && !rid.nil? && rid != 0
  router = ex.router_name rid
  intf = ex.interface_name_descr(rid, iid).join(" ")
  [ 14400, 86400, 86400*7, 86400*30 ].each do |interval|
    puts "<div class='interface'>"
    puts "<img src='rtgplot.cgi?id=#{rid}:#{iid}&title=#{router}+#{intf}&secs=#{interval}&old=#{old}' />"
    puts "</div>"
  end
elsif !rid.nil? && rid != 0
  router = ex.router_name rid
  puts "<h1>#{router}</h1>"
  ex.list_interfaces(rid).each do |intf|
    next if intf[:status] != 'active'
    next if intf[:speed] == 0
    puts "<div class='interface'>"
    puts "<a href='?rid=#{rid}&iid=#{intf[:id]}&old=#{old}'>"
    puts "<img src='rtgplot.cgi?w=400&h=200&id=#{rid}:#{intf[:id]}&title=#{intf[:name]}+#{intf[:description]}&secs=43200&old=#{old}' />"
    puts "</a>"
    puts "</div>"
  end
else
  ex.list_routers.each do |router|
    puts "<div class='router'><a href='?rid=#{router[:rid]}&old=#{old}'>#{router[:name]}</a></div>"
  end
end

puts "</body>"
puts "</html>"

