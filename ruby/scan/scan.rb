#!/usr/bin/env ruby 
# Scanning stuff
# 20150504
#
# Scanning documents in lineart, gray and color 
#
require 'rubygems'
require 'thor'
#
# Scan the document
def scanDocument(colordepth, resolution = 300, duplex = false)

  case colordepth
    when 'bw'
      scanmode = 'lineart'
    when 'gray'
      scanmode = 'gray'
    when 'color'
      scanmode = 'color'
    else
      abort "Unknown colordepth type: #{colordepth}."
  end

  case duplex
  when true
    batchmode = '-b'
    source    = 'ADF Duplex'
    redirect  = ''
  else
    batchmode = ''
    source    = 'ADF Front'
    redirect  = '> out1.tif'
    # scanimage --mode Lineart --resolution 300 -p --format tiff > out1.tif
  end
  command = "scanimage --source '#{source}' --mode #{scanmode} --resolution #{resolution} -p --format tiff #{batchmode} #{redirect}"
  `#{command}`

end

#
# Convert tiff files in the current PWD to a PDF
def convertTiff2Pdf(pdfOutputFile, resolution)

  # Merge tiff files if there are multiple
  command = 'tiffcp out*.tif out.tiff'
  `#{command}`

  # Convert Tiff file into PDF document
  command = "tiff2pdf -z -um -x #{resolution} -y #{resolution} -p A4 -F -o #{pdfOutputFile} out.tiff"
  `#{command}`

end

#
# Cleanup
def cleanup

  Dir.glob('./out*.tif').each do |filename|
    remove_file(filename, {:verbose => false})
  end
  remove_file('out.tiff', {:verbose => false})

end


#
# Main Class
class Scan < Thor

  include Thor::Actions

  class_option :duplex, :aliases => '-d', :type => :boolean, :default => false, :lazy_default => true, :desc => 'Scan in Duplex mode', :enum => ['true', 'false']
  class_option :resolution, :aliases => '-r', :type => :numeric, :default => '300', :desc => 'Set scan resolution', :enum => [100, 150, 200, 240, 300, 400, 600]
  class_option :overwrite, :aliases => '-o', :type => :boolean, :default => false, :lazy_default => true, :desc => 'Overwrite existing PDF file', :enum => ['true', 'false']

  desc 'color', 'Scan in color'
  def color(outputfile)

    abort("File #{outputfile} already exists. Abort.") unless (!File.exists?(outputfile) || options[:overwrite] )

    # Scan the file
    scanDocument('color', options[:resolution], options[:duplex])
    convertTiff2Pdf(outputfile, options[:resolution])
    cleanup

  end
 
  desc 'gray', 'Scan in Graymode'
  def gray(outputfile)

    abort("File #{outputfile} already exists. Abort.") unless (!File.exists?(outputfile) || options[:overwrite] )
    
    # Scan the file
    scanDocument('gray', options[:resolution], options[:duplex])
    convertTiff2Pdf(outputfile, options[:resolution])
    cleanup

  end

  desc 'bw', 'Scan in Lineart'
  def bw(outputfile)

    abort("File #{outputfile} already exists. Abort.") unless (!File.exists?(outputfile) || options[:overwrite] )

    # Scan the file
    scanDocument('bw', options[:resolution], options[:duplex])
    convertTiff2Pdf(outputfile, options[:resolution])
    cleanup

  end

end

Scan.start

