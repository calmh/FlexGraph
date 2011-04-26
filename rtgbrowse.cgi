#!/usr/bin/env ruby

require 'lib/gnuplotter'
require 'extractor/rtg'
require 'cgi'

def searchbox
  '<form id="searchbox" style="display: none">
  <p>Substring filter: <input type="text" name="search" id="search"></input></p>
  </form>'
end

def aggrlink
  '<div id="aggrlink" style="display: none">
  <a href="#">View the aggregate of these graphs</a>
  </div>'
end

$title = nil
def title(t)
  $title = t
end

$body = []
def body(t)
  if t.kind_of?(Array)
    $body += t
  else
    $body << t
  end
end

def matches(description, routers)
    matches = []
    descr_split = description.split /\b/
    descr_split.each do |possibility|
      if routers.include? possibility
        matches << [ possibility, routers[possibility][:rid] ]
      end
    end
    return matches
end

cgi = CGI.new
rid = cgi.params['rid'][0].to_i
iid = cgi.params['iid'][0].to_i
old = cgi.params['old'][0].to_i

ex = RTGExtractor.new
routers = {}
ex.list_routers.each do |router|
  routers[router[:name]] = router
end

if !iid.nil? && iid != 0 && !rid.nil? && rid != 0
  # Display single interface with different time scales
  router = ex.router_name rid
  name, descr = ex.interface_name_descr(rid, iid)
  intf = [ name, descr ].join(" ")
  title router + ' - ' + intf

  # Get a list of routers that match this interface description
  see_also = matches(intf, routers).sort.map { |name, mrid| "<a href=?rid=#{mrid}>#{name}</a>" }
  
  # If we got matches, format them as links and present them
  if !see_also.empty?
    body "<div class='seealso'><p class='quiet'>See also:</p>"
    body "<p>" + see_also.join(", ") + "</p>"
    body "</div>"
  end

  [ 14400, 86400, 86400*7, 86400*30, 86400*365 ].each do |interval|
    body "<div class='interface'>"
    body "<img src='rtgplot.cgi?id=#{rid}:#{iid}&title=#{router}+#{intf}&secs=#{interval}&old=#{old}' />"
    body "</div>"
  end
elsif !rid.nil? && rid != 0
  # Display all interfaces on a router
  router = ex.router_name rid
  title router

  body "<div class='hide'>"
  body "<h2>Device Aggregate</h2>"

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

  ids = intf_list.map { |name, intf| rid.to_s + ':' + intf[:id].to_s }.join "+"
  body "<img src='rtgplot.cgi?w=620&h=200&id=#{ids}&title=Aggregate+traffic&secs=86400&old=#{old}&only_i=1' />"
  body "<img src='rtgplot.cgi?w=620&h=200&id=#{ids}&title=Aggregate+packets&secs=86400&old=#{old}&only_i=1&type=pps' />"

  body "<h2>Interfaces</h2>"

  # Get list of routers that match any of the interface descriptions
  match_list = []
  intf_list.each do |s, i|
    match_list += matches(i[:description], routers)
  end

  # If we got matches, format them as links and present them
  if !match_list.empty?
    see_also = match_list.uniq.sort.map { |name, mrid| "<a href=?rid=#{mrid}>#{name}</a>" }
    body "<div class='seealso'><p class='quiet'>See also:</p>"
    body "<p>" + see_also.join(", ") + "</p>"
    body "</div>"
  end
  body "</div>"

  # Present each interface as an overview graph and a link to the full graph page
  intf_list.each do |intf_name_split, intf|
    body "<div class='interface filterable' id='#{intf[:name]} #{intf[:description]}'>"
    body "<a href='?rid=#{rid}&iid=#{intf[:id]}&old=#{old}'>"
    body "<img data-plot-id='#{rid}:#{intf[:id]}' src='rtgplot.cgi?w=400&h=200&id=#{rid}:#{intf[:id]}&title=#{intf[:name]}+#{intf[:description]}&secs=43200&old=#{old}' />"
    body "</a>"
    body "</div>"
  end
else
  # List all routers
  names = routers.keys.sort
  names.each do |name|
    router = routers[name]
    body "<div class='router filterable' id='#{name}'><a href='?rid=#{router[:rid]}&old=#{old}'>#{name}</a></div>"
  end
end

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

p.quiet {
  color: #555;
  font-size: small;
}

div.interface {
  float: left;
}

div.router {
  float: left;
  padding: 2px;
  width: 12em;
}

div.seealso {
  padding: 5px;
  margin: 5px;
  background: #ffb;
  border: 1px solid #ff8;
}

div.seealso p {
  margin: 2px;
}

div#aggrlink {
  padding: 5px;
  margin: 5px;
  background: #bbf;
  border: 1px solid #88f;
}

div#aggrlink a {
  color: #00a;
}

</style>
<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.5.2/jquery.min.js"></script>
<script type="text/javascript">
filter = function(text) {
  if (text == "") {
    $('.filterable').show();
    $('.hide').show();
    $('#aggrlink').hide();
  } else {
    $(".filterable[id!='" + text + "']").hide();
    $(".filterable[id*='" + text + "']").show();
    $('.hide').hide();

    var aggrs = "";
    var aggrcount = 0;
    $(".filterable[id*='" + text + "'] img").each(function() {
      var id = this.getAttribute('data-plot-id')
      if (aggrs.length > 0 ) {
        aggrs += '+';
      }
      aggrs += id;
      aggrcount += 1;
    });

    if (aggrcount > 1) {
      $('#aggrlink a').attr('href', 'rtgplot.cgi?id=' + aggrs + '&secs=86400&title=Aggregate+graph+for+' + text);
      $('#aggrlink').show();
    } else {
      $('#aggrlink').hide();
    }
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
HEADER
if !$title.nil?
  puts "<title>#{$title}</title>"
else
  puts "<title>RTG Browser</title>"
end
puts "</head>"
puts "<body>"
if !$title.nil?
  puts "<h1>#{$title}</h1>"
end
puts searchbox
puts "<div id='content'>"
puts aggrlink
puts $body.join "\n"
puts "</div>"
puts "</body>"
puts "</html>"

