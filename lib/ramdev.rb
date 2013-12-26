
class RamDev
  attr_reader :diskname, :ramdisk, :mountpoint
    #path to rc file, and 10 mb default size.

  def initialize(sufix = "_ramdev")
    @backupSuffix = sufix
  end

  def unbuild(rcpath)

  end

  def build(rcpath, size=10485760)
    load_runcom(rcpath)

    ramdisk = Ramdisk.new(mountpoint)

    ramdisk.allocate(10 * 1048576)
    ramdisk.format(diskname, :hfs)
    ramdisk.mount

    copy_folders if valid_paths?

    puts "RAM disk mounted at #{mountpoint}"
  end

  def load_runcom(rcpath)

    return if @loaded == true

    rc = YAML.load_file(rcpath)
    if rc.nil?
      @mountpoint = "/ramdev"
      @diskname   = "ramdev"
      @paths      ||= []
      @paths.push({ source: Dir.pwd, destination: "" })
    else
      @mountpoint = rc["ramdisk"]["mountpoint"]
      @diskname  = rc["ramdisk"]["name"]
        # TODO: Get size of paths and create default ramdisk size based it (2x)
      @paths     = rc["ramdisk"]["paths"]
      @loaded    = true
    end

  end

  def valid_paths?
    @paths.each do |p|
      src   = p["source"].gsub(/\/+$/,"")
      if File.exist?("#{src}#{@backupSuffix}")
        puts "A backup already exists for: '#{src}' at: '#{src}#{@backupSuffix}'"
        return false
      end
    end
    return true
  end

  def copy_folders()
    @paths.each do |p|
      src   = p["source"].gsub(/\/+$/,"")
      next if src.nil? || src.length < 1
      des   = p["destination"].gsub(/\/+$/,"").gsub(/^\/+/,"")
      name  = src.match(/([^\/\\]+)$/)[1]
      if des.length > 0
        des = mountpoint+"/#{des}"
        des = des.gsub(/\/{2,}/,"/")
      else
        des = mountpoint
      end
      des = File.absolute_path(des)
      print "Copying #{src}...\n"
      FileUtils.mkdir_p(des) unless File.exist?(des)
      IO.popen("rsync --progress -ra #{src} #{des}") do |rsync_io|
        until rsync_io.eof?
          line = rsync_io.readline
          line = line.gsub("\n","")
          next unless line =~ /to-check/
          m = line.match(/to-check=([0-9]+)\/([0-9]+)/)
          scale = (m[1].to_f / m[2].to_f)
          prog = "#{[9613].pack('U*')}" * ( (1.0 - scale) * 30.0).round

          prog += " " * (scale * 30.0).round
          print "#{prog}| #{des}/#{name}  "
          print "\r"
        end
      end
      print "\n"

      FileUtils.move(src, src+@backupSuffix)

      puts "Linking: #{name}"

      File.symlink("#{des}/#{name}", src)
    end
  end

end


# require 'etc'
# require 'yaml'
# require 'fileutils'


#class RamDev
  #-------
  # attr_reader :ramDiskSize, :sectors

  # def initialize
  #   @backupSuffix = "_backup_DEV"
  #   @systemInfo = SystemInfo.new
  #   @ramDiskSize = (@systemInfo.memory / 2)
  # end

  # def build(diskname = "x", mountpoint = "/x", paths = [])
  #   unbuild(diskname, mountpoint, paths)
  #   build = false

  #   if @ramDiskSize > 0
  #     @sectors = @ramDiskSize / 512

  #     ramdisk = `hdid -nomount ram://#{sectors}`.strip
  #     system "newfs_hfs -v '#{diskname}' #{ramdisk}"
  #     build = system "sudo mount -o noatime -t hfs #{ramdisk} #{mountpoint}"
  #     print "RAM disk mounted at #{mountpoint}\n"

  #     if build
  #       paths.each do |p|
  #         print "#{p}\n"
  #         src   = p["source"].gsub(/\/+$/,"")
  #         validate(src)
  #       end
  #       paths.each do |p|
  #         src   = p["source"].gsub(/\/+$/,"")
  #         next if src.nil? || src.length < 1
  #         des   = p["destination"].gsub(/\/+$/,"").gsub(/^\/+/,"")
  #         name  = src.match(/([^\/\\]+)$/)[1]
  #         if des.length > 0
  #           des = mountpoint+"/#{des}"
  #           des = des.gsub(/\/{2,}/,"/")
  #         else
  #           des = mountpoint
  #         end
  #         print "Copying #{src}...\n"
  #         FileUtils.mkdir_p(des) if !File.exist?(des)
  #         IO.popen("rsync --progress -ra #{src} #{des}") do |rsync_io|
  #           until rsync_io.eof?
  #             line = rsync_io.readline
  #             line = line.gsub("\n","")
  #             next unless line =~ /to-check/
  #             m = line.match(/to-check=([0-9]+)\/([0-9]+)/)
  #             scale = (m[1].to_f / m[2].to_f)
  #             prog = "#{[9613].pack('U*')}" * ( (1.0 - scale) * 30.0).round

  #             prog += " " * (scale * 30.0).round
  #             print "#{prog}| #{des}/#{name}  "
  #             print "\r"
  #           end
  #         end
  #         print "\n"

  #         FileUtils.move(src, src+@backupSuffix)

  #         puts "Linking: #{name}"

  #         File.symlink("#{des}/#{name}", src)
  #       end
  #     end
  #   end
  # end

  # def unbuild(diskname = "x", mountpoint = "/x", paths = [])
  #   paths.each do |p|
  #     print "#{p}\n"
  #     src   = p["source"].gsub(/\/+$/,"")
  #     next if src.nil? || src.length < 1
  #     des   = p["destination"].gsub(/\/+$/,"").gsub(/^\/+/,"")
  #     name  = src.match(/([^\/\\]+)$/)[1]

  #     if File.exists? src+@backupSuffix
  #       FileUtils.safe_unlink src if File.symlink?(src)
  #       if File.exist?(src)
  #         print "Conflict between #{src} and #{src+@backupSuffix}"
  #         next
  #       end
  #       FileUtils.move(src+@backupSuffix, src)
  #     end
  #   end

  #   unmount = `diskutil unmount force #{mountpoint}`
  #   if unmount =~ /Volume .* on (.*) unmounted/
  #     m = unmount.match(/Volume .* on (.*) unmounted/)
  #     system "hdiutil detach /dev/#{m[1]}"
  #   else
  #     print unmount
  #   end
  # end

  # private

  # def validate(src)
  #   if File.exist?("#{src}#{@backupSuffix}")
  #     abort "Stopping for safety. A backup already exists for: '#{src}' at: '#{src}#{@backupSuffix}'"
  #   end
  # end

#end


# if opts.ram?
#   print "Building RAM disk"
#   rd = RamDev.new opts[:ram]
#   rd.build(rc["ramdisk"]["name"],rc["ramdisk"]["mountpoint"],rc["ramdisk"]["paths"])
# elsif opts.fix?
#   print "fixing links"
#   rd = RamDev.new opts[:ram]
#   rd.unbuild(rc["ramdisk"]["name"],rc["ramdisk"]["mountpoint"],rc["ramdisk"]["paths"])
# end


# def getrc
#   si = SystemInfo.new
#   si.loadOrCreateRC
# end

# def build_ramdisk
#   rc = getrc
#   rd = RamDev.new #options?
#   rd.build(rc["ramdisk"]["name"],rc["ramdisk"]["mountpoint"],rc["ramdisk"]["paths"])
# end

# def teardown_ramdisk
#   rc = getrc
#   rd = RamDev.new #options?
#   rd.unbuild(rc["ramdisk"]["name"],rc["ramdisk"]["mountpoint"],rc["ramdisk"]["paths"])
# end

# -------------------

#require 'main'

# Main do
#   mode 'up' do
#     def run
#       puts 'building RAMDISK...'
#       build_ramdisk
#     end
#   end

#   mode 'down' do
#     def run
#       puts 'tearing down RAMDISK...'
#       teardown_ramdisk
#     end
#   end

#   mode 'aws' do
#     def run
#       puts 'do something with AWS...'
#     end
#   end

#   def run()
#     puts 'doing something different'
#   end
# end
# class SystemInfo

#   def memory
#     if @memory.nil?
#       r = `/usr/sbin/system_profiler SPHardwareDataType`.split("\n").collect { |s| s == "" ? nil : s.strip }.compact
#       r = r.collect { |s| s.split(":").collect { |ss| ss.strip }}
#       memstring = ""
#       r.each do |i|
#         memstring = i[1] if i[0] == "Memory"
#       end
#       @memory = memstring.match(/([0-9]+) GB/)[1].to_i * 1073741824
#     end
#     @memory
#   end

#   def home
#     @home ||= Dir.home(user)
#   end

#   def user
#     @user ||= Etc.getlogin
#   end

#   def loadOrCreateRC
#     rcpath = "#{home}/.devrc"
#     unless File.exist? rcpath
#       File.open(rcpath, "w") do |f|
#         f.puts '# This is a yaml format file with settings for "dev".'
#         f.puts '# See dev -h for more information.'
#       end
#     end
#     puts "Loading devrc: #{rcpath}"
#     YAML.load_file rcpath
#   end

# end
