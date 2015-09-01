require 'crawler/consumer/resourceconsumer'
require 'mini_magick'
require 'fileutils'
module Consumer
	class Images < ResourceConsumer
		def initialize(page,download_thread_limit=2,save_dir='.')
			super
			@urls=@page.images.map{|img| img[:url]}
			@current_select=@urls
			@images=@page.images
			@thumbnail=''
		end

		def enable_thumbnail(size='100x100',save_path='.',prefix='thumbnail')
			@thumbnail=size
			@thumbnail_prefix=prefix
			@thumbnail_save_path=save_path
			self
		end
		
		def consume(extname='.jpg')
			mimelist=['image/bmp','image/gif','image/jpeg','image/tiff','image/png']
			#if the file extname is empty,set the default extname
			filesaved,save_dir=super(mimelist,extname)
			return if filesaved==0 || save_dir.nil?
			unless @thumbnail.empty?
				images=Dir.glob(File.join(save_dir,'*'))
				savein= if @thumbnail_save_path == '.' 
								File.join(save_dir,'thumbnail')
							else
								@thumbnail_save_path
							end
				Dir.mkdir savein unless Dir.exist? savein
				images.each do |image|
					begin
						savename=File.join(savein,@thumbnail_prefix+File.basename(image))
						FileUtils.cp(image,savename)
						i=MiniMagick::Image.new(savename)
						i.thumbnail(@thumbnail)
					rescue
						next
					end
				end
			end
			return filesaved,save_dir
		end
	end
end
