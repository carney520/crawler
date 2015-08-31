require 'crawler/consumer/download'
require 'mechanize'
require 'crawler/page'
module Consumer
	class ResourceConsumer
		def initialize(page,save_dir='.',download_thread_limit=2)
			raise ArgumentError unless page.is_a? Page
			@page=page.clone
			#get all links from page
			@urls=page.links.map{|link| link[:url]}+page.images.map{|img| img[:url]}
			@current_select=@urls

			@save_dir=save_dir
			@download_thread_limit=download_thread_limit
			#the default formatter
			@formatter=proc do |uri,title,filename,extname|
				File.join("#{title[0..15]}","#{filename}")
			end
		end

		def saveto(path)
			@save_dir=path	
			self
		end

		def select(path=nil)
			@current_select=[]
			if block_given?
				@urls.each{|url|
					@current_select << url if yield url	
				}
			else
				if path.is_a? String
					@urls.each do |url|
						@current_select << url if url.path == path
					end
				elsif path.is_a? Regexp
					@urls.each do |url|
						@current_select << url if url.path =~ path
					end
				end
			end
			self
		end

		def formatter=(b)
			raise ArgumentError,'Argument not a Proc' unless b.is_a? Proc
			@formatter=b
		end

		def consume(mime,extname)
			#check extname
			extname.strip!
			raise ArgumentError.new("extname illegal") unless extname =~ /^\..+/
			urls=@current_select

			return if urls.nil? or urls.empty?
			urls.uniq!
			agent=Mechanize.new{|a|
				a.keep_alive=false
				#a.max_history=1
				a.user_agent_alias='Mac Safari'
			}

			if mime.is_a? Array
				mime.each{|m|
					agent.pluggable_parser[m.to_s]=Mechanize::Download
				}
			else
				agent.pluggable_parser[mime.to_s]=Mechanize::Download
			end

			filename=""
			filesaved=0

			download=Download.new(@download_thread_limit)
			urls.each_index do |index|
				url=urls[index]
				download.add(2) do
					#asynchronous download
					result=download.task do
						link=Crawler::Frontier.uri_compile(URI.decode(url.to_s))
						next nil if link.nil?
						#clone
						begin
							src=agent.get(link,[],nil,{'Host'=>link.host,
																	#anti hotlinking protection
																	'Referer'=>@page.uri.to_s
							})
							next nil unless src.is_a? Mechanize::Download
							src
						rescue Mechanize::ResponseCodeError
							case $!.response_code
							when '202' then
								sleep 1
								retry
							else
								$logger.warn("[Download] Abandon [#{$!.response_code}]-#{$!.message}-host=#{link.host}-referer=#{@page.uri.to_s}\n")
								nil
							end
						rescue
							$logger.warn("[Download] Skip error raise(#{$!.message})-#{link.to_s[0..15]}-#{@page.uri.to_s}\n")
							next nil
						end
					end
					#now save file
					if result
						#if extname is empty,add extname
						save_name=File.extname(result.filename).empty? ? result.filename+extname : result.filename
						full_save_path=@formatter.call(url,@page.title,save_name,extname,index)

						unless full_save_path.is_a? String
							#if formatter return a illegal string
							$logger.error("[Download] Formatter return a illegal string#{__LINE__}")
							full_save_path=File.join("#{@page.title[0..15]}","#{save_name}")
						end

						filename=File.join(@save_dir,full_save_path)
						begin
							result.save(filename)
							filesaved+=1
							$logger.info("[Download] Saved - #{filename[0..64]+'...'}\n")
						rescue Errno::EACCES
							raise Errno::EACCES,"check the permission to access #{@save_dir}"
						rescue
							$logger.error("[Download] Error(#{$!.class}) raised when save #{save_name[0..36]} #{$!.message}\n")
						end
					end
				end
			end #end of each
			download.scheduler
			agent.shutdown

			resource_save_dir=File.expand_path('..',filename)
			#delete repeat file
			FileUtils.rm Dir.glob(File.join(resource_save_dir,'*.[1-9]'))
			#return resource_save_dir
			return filesaved,resource_save_dir
		#rescue
			#puts "error-- #{$i.class}"
		end #end of consume
	end #end of ResourceConsumer

end
