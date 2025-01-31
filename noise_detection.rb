#!/usr/bin/ruby -w
#
# Copyright (C) 2013 Marco Mornati [http://www.mornati.net]
# Based on Thomer M. Gil First [http://thomer.com/] version template
#
# Oct  05, 2012: Initial version
#
# This program is free software. You may distribute it under the terms of
# the GNU General Public License as published by the Free Software
# Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# This program detects the presence of sound and invokes a program.
#

require 'getoptlong'
require 'optparse'
require 'net/smtp'
require 'logger'
require 'date'


HW_DETECTION_CMD = "cat /proc/asound/cards"
# You need to replace MICROPHONE with the name of your microphone, as reported
# by /proc/asound/cards
SAMPLE_DURATION = 5 # seconds
FORMAT = 'S16_LE'   # this is the format that my USB microphone generates
RECORD_FILENAME='/home/pi/noise'
LOG_FILE='/home/pi/noise_detector.log'

logger = Logger.new(LOG_FILE)
logger.level = Logger::DEBUG

logger.info("Noise detector started @ #{DateTime.now.strftime('%d/%m/%Y %H:%M:%S')}")


def self.check_required()
  if !File.exist?('/usr/bin/arecord')
    warn "/usr/bin/arecord not found; install package alsa-utils"
    exit 1
  end

  if !File.exist?('/usr/bin/sox')
    warn "/usr/bin/sox not found; install package sox"
    exit 1
  end

  if !File.exist?('/proc/asound/cards')
    warn "/proc/asound/cards not found"
    exit 1
  end
  
end

# Parsing script parameters
options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: noise_detection.rb -m ID [options]"

  opts.on("-m", "--microphone SOUND_CARD_ID", "REQUIRED: Set microphone id") do |m|
    options[:microphone] = m
  end
  opts.on("-s", "--sample SECONDS", "Sample duration") do |s|
    options[:sample] = s
  end
  opts.on("-n", "--threshold NOISE_THRESHOLD", "Set Activation noise Threshold. EX. 0.1") do |n|
    options[:threshold] = n
  end
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-d", "--detect", "Detect your sound cards") do |d|
    options[:detection] = d
  end
  opts.on("-t", "--test SOUND_CARD_ID", "Test soundcard with the given id") do |t|
    options[:test] = t
  end
  opts.on("-k", "--kill", "Terminating background script") do |k|
    options[:kill] = k
  end
end.parse!

if options[:detection]
    puts "Detecting your soundcard..."
    puts `#{HW_DETECTION_CMD}`
    exit 0
end

#Check required binaries
check_required()

if options[:sample]
    SAMPLE_DURATION = options[:sample]
end

if options[:threshold]
    THRESHOLD = options[:threshold].to_f
end

if options[:test]
    puts "Testing soundcard..."
    puts `/usr/bin/arecord -D plughw:#{options[:test]},0 -d #{SAMPLE_DURATION} -f #{FORMAT} 2>/dev/null | /usr/bin/sox -t .wav - -n stat 2>&1`
    exit 0
end

optparse.parse!

#Now raise an exception if we have not found a host option
raise OptionParser::MissingArgument if options[:microphone].nil?

if options[:verbose]
   logger.debug("Script parameters configurations:")
   logger.debug("SoundCard ID: #{options[:microphone]}")
   logger.debug("Sample Duration: #{SAMPLE_DURATION}")
   logger.debug("Output Format: #{FORMAT}")
   logger.debug("Noise Threshold: #{THRESHOLD}")
   logger.debug("Record filename (overwritten): #{RECORD_FILENAME}")
end

#Starting script part
loop do
    `/usr/bin/arecord -D plughw:#{options[:microphone]},0 -d #{SAMPLE_DURATION} -f #{FORMAT} -t wav #{RECORD_FILENAME}.wav 2>/dev/null`
    out = `/usr/bin/sox -t .wav #{RECORD_FILENAME}.wav -n stat 2>&1`
    out.match(/Maximum amplitude:\s+(.*)/m)
    amplitude = $1.to_f
    print("Detected amplitude: #{amplitude}") if options[:verbose]
    if amplitude > THRESHOLD
        print ("Sound detected!!!")

	`lame #{RECORD_FILENAME}.wav #{RECORD_FILENAME}.mp3`
	`drive upload --file #{RECORD_FILENAME}.mp3`
    else
      logger.debug("No sound detected...")
    end
end
