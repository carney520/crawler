require 'crawler/consumer/resourceconsumer'
require 'crawler/frontier'
require 'crawler/consumer/articleextractor'
require 'crawler/consumer/saver'
require 'crawler/consumer/ext/images'
require 'crawler/consumer/ext/article'

module Consumer
	class Delegate
		def initialize(task)
			@task={}
			@task['.']=task.delete('.')
			task.each do |key,value|
				Crawler::Frontier.domains.update(key) unless Crawler::Frontier.domains.include?(key)
				ip=Crawler::Frontier.domains[key]
				@task[ip]=value
			end
		end

=begin
				save_dir=global[:save] || '.'
				save_formatter=global[:save_formatter]
				download=Images.new(page).saveto(save_dir).select(/^\/uploads/).enable_thumbnail
				download.formatter=save_formatter if save_formatter && save_formatter.is_a?(Proc)
				download.consume
				if global.has_key?(:mime) and global[:mime]
					download=ResourceConsumer.new(page).saveto(save_dir)
					download.formatter=save_formatter if save_formatter && save_formatter.is_a?(Proc)
					global[:mime].each do |key,value|
						download.select(value[0]).consume(key,value[1])
					end
				end
=end

		def action(page)
			raise ArgumentError,'page must be an instance of Consumer::Page' unless page.is_a? Page
			#global
			@task['.'].call(page) if @task['.'] && @task['.'].is_a?(Proc)
			#for specify host
			host=page.uri.ip
			path=page.uri.path
			if @task[host]
				@task[host].each do |key,|
					if path==key or path.start_with?(key+'/')
						$logger.info("[Consumer] Consuming #{page.uri.to_s} (#{page.title[0..15]+'...'})\n")
						@task[host][key].call(page) if @task[host][key].is_a?(Proc)
					end
				end
			end
		end
	end
end
