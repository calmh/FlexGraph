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
body {
  font-family: Calibri, Helvetica, sans-serif;
}

a {
  text-decoration: none;
}

a img {
  border: none;
}

div.interface {
  float: left;
}

div.router {
  float: left;
  padding: 2px;
  width: 12em;
}
</style>
<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.5.2/jquery.min.js"></script>
<script type="text/javascript">
filter = function(text) {
  if (text == "") {
    $('.filterable').show();
  } else {
    $(".filterable[id!='" + text + "']").hide();
    $(".filterable[id*='" + text + "']").show();
  }
}

$(document).ready(function() {
  if ($('.filterable').length > 0) {
    var sb = $('#search')
    sb.keyup(function() {
      filter(sb.val());
    });
    filter(sb.val());
    $('#searchbox').show();
    sb.focus();
    }
});
</script>
<title>RTG Browser</title>
</head>
<body>
<form id="searchbox" style="display: none">
<p>Substring filter: <input type="text" name="search" id="search"></input></p>
</form>
HEADER

cgi = CGI.new
rid = cgi.params['rid'][0].to_i
iid = cgi.params['iid'][0].to_i
old = cgi.params['old'][0].to_i

ex = RTGExtractor.new

if !iid.nil? && iid != 0 && !rid.nil? && rid != 0
  # Display single interface with different time scales
  router = ex.router_name rid
  intf = ex.interface_name_descr(rid, iid).join(" ")
  [ 14400, 86400, 86400*7, 86400*30, 86400*365 ].each do |interval|
    puts "<div class='interface'>"
    puts "<img src='rtgplot.cgi?id=#{rid}:#{iid}&title=#{router}+#{intf}&secs=#{interval}&old=#{old}' />"
    puts "</div>"
  end
elsif !rid.nil? && rid != 0
  # Display all interfaces on a router
  router = ex.router_name rid
  puts "<h1>#{router}</h1>"

  # Sort the interface list as numerically as possible
  # i.e. GigabitEthernet1/0/2 before GigabitEthernet1/0/10
  intf_list = []
  ex.list_interfaces(rid).each do |intf|
    next if intf[:status] != 'active'
    next if intf[:speed] == 0
    name_split = intf[:name].gsub(/\s+/, ' ').split(/\b/).map { |x| (x.to_i if x =~ /^\d+$/) or x }
    intf_list << [ name_split, intf ]
  end
  intf_list.sort!

  intf_list.each do |intf_name_split, intf|
    puts "<div class='interface filterable' id='#{intf[:name]} #{intf[:description]}'>"
    puts "<a href='?rid=#{rid}&iid=#{intf[:id]}&old=#{old}'>"
    puts "<img src='rtgplot.cgi?w=400&h=200&id=#{rid}:#{intf[:id]}&title=#{intf[:name]}+#{intf[:description]}&secs=43200&old=#{old}' />"
    puts "</a>"
    puts "</div>"
  end
else
  # List all routers
  ex.list_routers.each do |router|
    puts "<div class='router filterable' id='#{router[:name]}'><a href='?rid=#{router[:rid]}&old=#{old}'>#{router[:name]}</a></div>"
  end
end

puts "</body>"
puts "</html>"

