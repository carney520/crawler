require 'mechanize'
require 'singleton'
require 'crawler/exception'

class Crawler::Agent < Mechanize
	include Singleton
	attr_accessor :switch_threshold,:proxy_test_url
	def initialize
		super
		@proxy_pool=[]
		@proxy_test_url="www.baidu.com"
		#add default proxy,nonuse-proxy
		@user_agent_pool=[]
		AGENT_ALIASES.each_key{|key| @user_agent_pool << key}
		@switch_threshold=100
		yield self if block_given?
		add_proxy(nil,nil)
	end

	def allow_robots
		self.robots=(true)
	end

	def test_proxy(address,port,user=nil,pass=nil)
		http=Net::HTTP::Proxy(address,port,user,pass).start(@proxy_test_url)
		http.head('/index.html').is_a? Net::HTTPSuccess
	end

	def add_proxy(address,port,user=nil,pass=nil)
		if test_proxy(address,port,user,pass)
			puts("[Agent] Proxy(#{address}:#{port}) available\n")
			@proxy_pool << {:addr=>address,:port=>port,:user=>user,:pass=>pass}
		end
	end

	def add_user_agent_alias(alias_name,str)
		AGENT_ALIASES[alias_name]=str
		@user_agent_pool << alias_name
	end

	def auto_switch_user_agent
		@auto_switch_user_agent=true
	end


	def shape_shift!
		@count||=0
		@count+=1
		return unless @count >= @switch_threshold
		@count=0
		unless @proxy_pool.empty?
			#switch proxy agent
			index=Random.rand(@proxy_pool.size)
			proxy=@proxy_pool[index]
			set_proxy(proxy[:addr],proxy[:port],proxy[:user],proxy[:pass])
			$logger.debug("[Agent] switched proxy(#{proxy[:addr]}:#{proxy[:port]})\n")
		end
		#switch user agent
		if @auto_switch_user_agent
			index=Random.rand(@user_agent_pool.size)
			user_agent=@user_agent_pool[index]
			self.user_agent_alias=(user_agent)
			$logger.debug("[Agent] switched User-agent(#{user_agent})\n")
		end
	end

	def get(uri,expect_type=Mechanize::Page,*args)
		offline_retry_count=0
		begin
			#auto shift the User-Agent and Proxy
			shape_shift!
			page=super(uri,*args)
		rescue Mechanize::RobotsDisallowedError
			$logger.warn("[Agent] Rotbots disallow:#{uri.to_s}\n")
			return nil
		rescue Mechanize::ResponseCodeError
			case $!.response_code
			when '202' then
				#the request non finish,block to read
				sleep 1
				retry
			else
				$logger.warn("[Agent] Abandon [#{$!.response_code}]-#{uri.to_s}\n")
				return nil
			end
		rescue Mechanize::ResponseReadError
			#problem with content-length
			page=$!.force_parse()
		rescue Net::OpenTimeout
			$logger.warn("[Agent] OpenTimeout #{uri.to_s}\n")
			return nil
		rescue Net::ReadTimeout
			$logger.warn("[Agent] ReadTimeout #{uri.to_s}\n")
			return nil
		rescue ThreadError
			#open_timeout will create a Thread
			sleep 1
			retry
		rescue SocketError
			#the network break up
			#if the network is break up,retry 3 times
			offline_retry_count+=1
			if offline_retry_count == 3
				raise OfflineError
			else
				retry
			end
		rescue 
			$logger.warn("[Agent] Error(#{$!.class}:#{$!.message}) raised when access #{uri.to_s}\n")
			return nil
		end #end of begin

		if page.is_a? expect_type
			page
		else
			nil
		end
	end
end
