#!/usr/bin/env ruby
# == revealmgmt.rb
#
# Script for working with reveal.js
#
# === Parameter
#
# [*init*]
#   Fetches a new instance of reveal.js from github
#
# [*pack*]
#   Strips away all junk and wraps up the presentation into a tgz file.
#   License and Readme file are included.
#
require "thor"

class RevealJS < Thor

  GITHUBURL = 'https://github.com/hakimel/reveal.js.git'

  # 
  # Wrap up the presentation into a tgz file
  desc 'pack','Package the current presentation'
  long_desc <<-LONGDESC

  Wrapps up the presentation in a compressed tgz file.

  === Naming

  The naming of the compressed file follows the following scheme

     <timestamp>-<presentation_title>.tgz

  The timestamp is generated at the moment when the created file is being
  created. 

  presentation_title: The string for 'presentation_title' is fetched from the 
    actual title of the presentation in 'index.html'. Whitespaces are replaced
    with underscores '_' and all characters converted to lowercase characters.

  === Parameters

  outputdir: Specified the directory where to pu the compressed file. If this
    parameter is omitted, the compressed file will be created in the current
    working directory.

  timestamp: Specifies if the timestamp shall be used in the filename of the
    compressed file. If this parameter is set to 'fault', the timestamp in the
    filename will be omitted. Default: true
 
  title: Specfies the string to use at title for the compressed file instead
    of the Presentation title itself.

  LONGDESC
  method_option :outputdir, :aliases => '-o', :type => :string, :required => false, :default => '.'
  method_option :timestamp, :aliases => '-h', :type => :boolean, :required => false, :default => true
  method_option :title, :aliases => '-t', :type => :string, :required => false
  def pack(foldername = '.')
    if not File.exists?(foldername.chomp('/') + '/.git') 
      puts 'not a reveal.js git repository'
    end
    if not File.exists?(foldername.chomp('/') + '/js/reveal.js')
      puts 'Not a reveal.js instance (reveal.js) not found)'
    end

    packagefiles = [
      'css',
      'index.html',
      'js',
      'lib',
      'LICENSE',
      'plugin',
      'README.md'
    ]

    # Pack optional images and videos
    File.exists?('./images') ?  packagefiles.push('images') : ''
    File.exists?('./videos') ? packagefiles.push('videos') : ''

    # Set archive title
    archivetitle = 'reveal.js-presentation'
    if not options[:title].nil? 
      archivetitle = options[:title].gsub(' ','_').downcase
    else 
      presentationtitle = `grep -i -m 1 '<title>' index.html`
      archivetitle      = presentationtitle.scan(/<title>([^<>]*)<\/title>/imu).flatten.select{|x| !x.empty?}.join('').downcase.gsub(' ','_')
    end

    archivefiles = packagefiles.join(' ')
    archivedate  = options[:timestamp] ? Time.now.strftime("%Y%m%d%H%M%S") + '-' : ''
    subdir       = archivetitle
    archive      = options[:outputdir].chomp('/') + '/' + archivedate + archivetitle + '.tgz'

    # Pack the files
    `tar -czf #{archive} --transform 's,^,#{subdir}/,' #{archivefiles}`

    if File.exists?(archive)
      puts "File '#{archive}' has been created."
    else
      puts "Error creating file '#{archive}'."
    end

  end


  #
  # Fetch the latest version of reveal.js from GitHub and deploy it locally
  desc 'init','Create a new RevealJS instance'
  method_option :outputdir, :aliases => '-o', :type => :string, :required => false, :default => 'github.com.hakimel.reveal.js'
  def init(folder = '.')

    if File.exists?(folder.chomp('/') + '/.git')
      abort('Current folder is a already a GIT repository. Abort.')
    end

    if File.exists?(options[:outputdir])
      abort("Output location '#{options[:outputdir]}' already exists. Abort.")
    end

    puts "Cloning reveal.js from GitHub into '#{options[:outputdir]}'."
    `git clone --depth 1 #{GITHUBURL} #{options[:outputdir]}`

  end
end

RevealJS.start(ARGV)

