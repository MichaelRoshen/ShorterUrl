require 'rubygems'
require 'data_mapper'
require 'rest_client'
require 'xmlsimple'

DataMapper.setup :default, "mysql://root:123456@localhost/shorter_url"
DIRTY_WORDS = ["hello"]

class Url
  include DataMapper::Resource

  property :id, Serial
  property :original, String,:length => 255
  belongs_to :link ,:required => false
end


class Link
  include DataMapper::Resource

  property :id, Serial
  property :identifier, String
  property :created_at, Date
  has 1, :url
  has n, :visits

  def self.shorten(original, custom=nil)
    url = Url.first(:original => original)
    return url.link if url
    link = nil
    if custom
      raise 'Someone has already taken this custom URL, sorry' unless Link.first(:identifier => custom).nil?
      raise 'Tis custom URL is not allowed because if profanity' if DIRTY_WORDS.include? custom
      transaction do 
        link = Link.new(:identifier => custom)
        link.url = Url.creat(:original => original)
        link.save
      end
    else
      transaction do 
        link = create_link(original)
      end
    end
    return link
  end

  def self.create_link(original)
    url = Url.create(:original => original)
    if Link.first(:identifier => url.id.to_s(36)).nil? or !DIRTY_WORDS.include? url.id.to_s(36)
      link = Link.new(:identifier => url.id.to_s(36))
      link.url = url
      link.save
      return link
    else
      create_link(original)
    end
  end
  
end

class Visit
  include DataMapper::Resource

  property :id, Serial
  property :created_at, Date
  property :ip, String
  property :contry, String
  belongs_to :link ,:required => false


  after :create, :set_country

  def set_country
    xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"
    self.contry = XmlSimple.xml_in(xml.to_s, { 'ForceArray' => false })['featureMember']['Hostip']['countryAbbrev']
    self.save
  end

  def self.count_by_date_with(identifier,num_of_days)
    visits = repository(:default).adapter.select("SELECT  date(created_at) as date, count(*) as count FROM visits where link_id = #{identifier}
      and created_at between CURRENT_DATE-#{num_of_days} and CURRENT_DATE+1 group by date(created_at)")
    dates = (Date.today-num_of_days..Date.today)
    results = {}
    dates.each { |date|
      visits.each {|visit| results[date] = visit.count if visit.date == date}
      results[date] = 0 unless results[date]
    }
    results.sort.reverse
  end

  def self.count_by_country_with(identifier)
    repository(:default).adapter.select("select contry, count(*) as count from visits where link_id = #{identifier} group by contry")
  end

  def self.count_days_bar(identifier,num_of_days)
    visits = count_by_date_with(identifier,num_of_days)
    data, labels = [], []
    visits.each {|visit| data << visit[1]; labels << "#{visit[0].day}/#{visit[0].month}" }
    "http://chart.apis.google.com/chart?chs=820x180&cht=bvs&chxt=x&chco=a4b3f4&chm=N,000000,0,-1,11&chxl=0:|#{labels.join('|')}&chds=0,#{data.sort.last+10}&chd=t:#{data.join(',')}"
  end

  def self.count_country_chart(identifier,map)
    countries, count = [], []
    count_by_country_with(identifier).each {|visit| countries << visit.contry; count << visit.count }
    chart = {}
    chart[:map] = "http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm=#{map}&chco=FFFFFF,a4b3f4,0000FF&chld=#{countries.join('')}&chd=t:#{count.join(',')}"
    chart[:bar] = "http://chart.apis.google.com/chart?chs=320x240&cht=bhs&chco=a4b3f4&chm=N,000000,0,-1,11&chbh=a&chd=t:#{count.join(',')}&chxt=x,y&chxl=1:|#{countries.reverse.join('|')}"
    return chart
  end
end

DataMapper.auto_migrate!
DataMapper.finalize

