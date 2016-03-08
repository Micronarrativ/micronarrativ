#!/usr/bin/env ruby
# dot2png-pandoc.rb
#
# == Description
#
# Renders a PNG file from a graphviz *.dot file with a maximum size of 1800px
#   and dpi of 300 to fit on a A4 pandoc rendered pdf document from markdown.
#   In addition the filename of the dot file is printed on the bottom right of
#   the diagram.
#   
# == Requirements
#
# * convert (ImageMagick)
# * dot
#
# == Contributors
#
# Daniel Roos <mn-github@micronarrativ.org>
#
require 'tempfile'

# Default values
imageResolution     = 300
imageSizeWidthInch  = 6
imageSizeHeightInch = 6

# ----------------------------------------------------------------------------

def help
  puts 'Help: '
  puts ''
  puts '  ' + File.basename(__FILE__) + ' <dotfile>'
end

# ----------------------------------------------------------------------------

if ARGV.size == 0 # Ups, no file as parameter

  help()
  exit 0

elsif ARGV.size > 1 # no more than one file at atime

  puts 'Only one input file allowed.'
  help()
  exit 1

elsif File.extname(ARGV[0]) != '.dot' # Ups, wrong file

  puts 'Input file is not a .dot file.'
  help()
  exit 1

else # Everything is fine

  inputFile     = ARGV[0]
  outputFile    = inputFile.gsub(/\.dot$/, '.png')
  temporaryFile = Tempfile.new('')
  
  # Render image in default size
  `dot -Tpng -Gsize=#{imageSizeWidthInch},#{imageSizeHeightInch}\\! -Gdpi=#{imageResolution} #{inputFile} > #{temporaryFile.path}`

  # Get the image dimension of the PNG
  imageDimension = IO.read(temporaryFile.path)[0x10..0x18].unpack('NN')
  
  # Change the image:
  # 1. Update ExifData with resolution
  # 2. Add 50 pixel to the bottom
  # 3. Align image to the top
  # 4. Write in lightgray the filename to the bottom right
  #    in fontsize 8 and a margin of 8px
  `convert -units PixelsPerInch \
    #{temporaryFile.path} \
    -density #{imageResolution} \
    -extent #{imageDimension[0]}x#{imageDimension[1]+50} \
    -gravity north \
    -fill lightgray \
    -gravity southeast \
    -pointsize 8 \
    -annotate +8+8 "#{File.basename(inputFile)}" \
    #{outputFile}`
  
  # Information
  puts 'Output: ' + outputFile

end

