require 'mysql'
require 'date'
require 'yaml'

class NQAExtractor
  def nqa_data(hid, pid, secs)
    start = Time.now.to_i - secs
    rows = []
    res = connection.query("SELECT unix_timestamp(end_date) as time, 100*(probes-success)/probes, min_response, med_response, max_response FROM results WHERE host_id = #{hid} AND probe_id = #{pid} AND unix_timestamp(end_date) > #{start} ORDER BY time")
    res.each { |r| rows << [ r[0].to_i, r[1].to_i, r[2].to_i, r[3].to_i, r[4].to_i ]}
    return rows
  end

  def connection
    @dbconf ||= YAML.load_file('nqaextractor.cfg')
    @connection ||= Mysql::new @dbconf['host'], @dbconf['user'], @dbconf['pass'], @dbconf['database']
  end
end
