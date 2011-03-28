require 'mysql'
require 'date'
require 'yaml'

class RTGExtractor
  def traffic_data(rid, iid, secs)
    in_octets = averaged_rate "ifInOctets", rid, iid, secs, conf['average_seconds']
    out_octets = averaged_rate "ifOutOctets", rid, iid, secs, conf['average_seconds']
    return [ in_octets, out_octets ]
  end

  def averaged_rate(table, rid, iid, secs, interval)
    start = Time.now.to_i - secs
    rows = []
    res = connection.query "SELECT (CAST(UNIX_TIMESTAMP(dtime) / #{interval.to_i} AS SIGNED)) * #{interval.to_i} AS avgtime, AVG(rate) FROM #{table}_#{rid} WHERE id = #{iid.to_i} AND dtime > FROM_UNIXTIME(#{start.to_i}) GROUP BY avgtime ORDER BY avgtime"
    res.each { |r| rows << [ r[0].to_i, r[1].to_i ]}
    return rows
  end

  def router_name(router_id)
    res = connection.query "SELECT name FROM router WHERE rid = #{router_id.to_i}"
    if res.num_rows == 1
      row = res.fetch_row
      return row[0].to_s
    end
    return nil
  end

  def interface_name_descr(router_id, interface_id)
    res = connection.query "SELECT name, description FROM interface WHERE rid = #{router_id.to_i} AND id = #{interface_id.to_i}"
    if res.num_rows == 1
      row = res.fetch_row
      return [ row[0].to_s, row[1].to_s ]
    end
    return nil
  end

  def connection
    @connection ||= Mysql::new conf['host'], conf['user'], conf['pass'], conf['database']
  end

  def conf
    @conf ||= YAML.load_file('rtgextractor.cfg')
  end
end
