require 'thread'
require 'redis'
require 'digest'
require 'resolv'
require 'yaml'  #to serialize object,so we can save into redis 
require 'ipaddr' #verify the ipaddr
require 'net/http' #for Domain
require 'uri'

URI.class_eval{
	attr_accessor :ip
}


class UnvisitedQueue
	def initialize(db)
		@db=db
		@setname='unvisits'
		@mutex=Mutex.new
		@cond=ConditionVariable.new
	end

	def push(obj)
		@mutex.synchronize {
			@db.sadd(@setname,obj.to_yaml)	
			@cond.signal
		}
		obj
	end

	def shift
		@mutex.synchronize{
			#wait 60 seconds
			#if timeout,stop anyway
			@cond.wait(@mutex,20) if empty?
			data=@db.spop(@setname)
			return nil if data.nil?
			YAML.load(data)
		}
	end

	def empty?
		return false if @db.scard(@setname) > 0
		true
	end
	def clear!
		@mutex.synchronize{
			@db.del(@setname)
		}
	end

	def get_all
		@db.smembers(@setname).map{
			|item|
			YAML.load(item)
		}
	end
	def size
		@db.scard(@setname)
	end
	alias_method :count,:size
	alias_method :lenght,:size
end

class VisitedQueue
	def initialize(db)
		@lock=Mutex.new
		@db=db
		@tablename='visiteds'
	end

	def push(link)
		@lock.synchronize {
			@db.hset(@tablename,link,1)
		}
		true
	end

	def include?(link)
		@db.hexists(@tablename,link)
	end

	def clear!
		@lock.synchronize{
			@db.del(@tablename)			
		}
	end

	def get_all
		@db.hgetall(@tablename)
	end
	def size
		@db.hlen(@tablename)
	end
	alias_method :count,:size
	alias_method :lenght,:size
end

class Domains
	def initialize(check_valid_period=43200)
		@db=Redis.new
		@tablename='domains'
	end

	def include?(host)
		@db.hexists(@tablename,host)
	end

	def push(host,ip)
		@db.hsetnx(@tablename,host,ip)
	end
	alias_method :[]=,:push

	def get(host)
		@db.hget(@tablename,host)
	end
	alias_method :[],:get

	def delete!(host)
		@db.hdel(@tablename,host)
	end

	def clear!
		@db.del(@tablename)			
	end

	def each
		it=@db.hgetall(@tablename).each
		if block_given?
			it.each do
				|key,value|
				yield key,value
			end
		else
			it
		end
	end

	def self.up?(url)
		net=Net::HTTP.new(url)
		net.open_timeout=3
		net.head('/').is_a? Net::HTTPSuccess
	rescue 
		false
	end

	def update(host)
		unless include?(host)
			#get ipaddress from domain
			begin
				#some website don't allow to access by ip
				#so we should get site with Host header
				ip=Resolv.getaddress(host)
				self[host]=ip
				#self[ip]=host
			rescue
				self[host]=host
			end
		end
	end
end

class Crawler::Frontier
	attr_reader :unvisits,:visiteds
	self.class.class_eval{attr_reader :domains}
	@domains=Domains.new()

	def initialize(dbname,unvisits_queue=UnvisitedQueue,visiteds_queue=VisitedQueue,evaluate=nil)
		raise ArgumentError unless dbname.is_a? Fixnum
		#initial redis connect
		redis=Redis.new
		redis.select(dbname)
		@redis=redis

		@unvisits=unvisits_queue.new(@redis)
		@visiteds=visiteds_queue.new(@redis)
		@encry=lambda do |url|
			#use ip to avoid url repeatation
			url=url.clone
			url.host=url.ip
			Digest::MD5.hexdigest(url.to_s.split('#').first)
		end
	end

	def shutdown
		@redis.quit
	end

	def clear!
		@unvisits.clear!
		@visiteds.clear!
	end

	def self.uri_compile(url)
		#check the url
		#url=url.clone
		begin 
			url=URI(url) unless url.is_a? URI
		rescue URI::InvalidURIError
			#the url is illegal
			return nil
		end
		#lack of host
		return nil if url.host.nil? || url.host.empty?
		
		#ok now the url is no problems

		host=url.host

		#check if the host is ipaddr
		if host =~ Resolv::AddressRegex
			return url
		end
		
		#no a ipaddress
		@domains.update(host)
		#url.host=@domains[host]
		url.ip=@domains[host]
		url
	end

	def push(url)
		#return a URI instance
		url=Crawler::Frontier.uri_compile(url)
		return false if url.nil?
		#verify
		if allow?(url) && !visited?(url) && !deny?(url)
			@unvisits.push(url)
			return true
		end
		false
	end

	def shift
		@unvisits.shift
	end

	def empty?
		@unvisits.empty?
	end

	def unvisits_size
		@unvisits.size
	end

	def unvisits_clear!
		@unvisits.clear!
	end


	def visited(url)
		@visiteds.push(@encry.call(url))
	end
	
	def visited?(url)
		@visiteds.include?(@encry.call(url))
	end

	def visiteds_size
		@visiteds.size
	end

	def visiteds_clear!
		@visiteds.clear!
	end

	def filter_compile(filter)
		raise TypeError unless filter.is_a? LinkFilter	
		#link=={
		#	"http://www.example.com"=>{
		#		'/path'=>'query.html'
		#	}
		#}

		@allows=filter.allows
		@denies=filter.denies
	end
	
	def allow?(url)
		#if @allows is empty allow all
		return true if @allows.empty?
		check(url,@allows)	
	end

	def deny?(url)
		check(url,@denies)
	end

	private
	def check(url,list)
		raise Exception,'@allows nonexist,call filter_compile(filter) before' unless @allows
		return false unless list.has_key?(url.host)

		#if if uri is root
		#return true if url.path=="" or url.path=="/"
		list[url.host].each do |path,query|
			#check if root
			return true if url.path=="" and list[url.host].has_key?('/')
			if url.path==path or url.path.start_with?(path+'/')
				return true if query=='None' or url.query.nil? or url.query.start_with?(query)
			end
		end
		false
	end
end


HostFormatError=Class.new(Exception)
class LinkFilter 
	attr_reader :allows,:denies
	def initialize(allow,deny)
		@allows={}
		@denies={}

		#check
		process=lambda do |source,target|
			source.is_a? Hash and	source.each do |host,value|
				url=Crawler::Frontier.uri_compile(host)
				raise HostFormatError if url.nil?
				host=url.host
				target[host]={}
				value.is_a? Hash and value.each do |path,query|
					path=path.to_s.strip
					path='/'+path if path !~ /^\/.*/
					query.to_s.strip! unless query.nil?
					target[host][path]=query ? query : 'None'
				end
			end
		end
		process.call(allow,@allows)
		process.call(deny,@denies)
	end
end
