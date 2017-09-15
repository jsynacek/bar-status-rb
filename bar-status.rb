#!/home/jsynacek/tools/bin/ruby
# Custom i3 bar status script.
# Requires the following binaries: nmcli, pactl, xkblayout, brightness
# Also requires Font Awesome.

require 'json'

# Options.
$separator_width = 25
$interval = 1

# Solarized.
$blue    = '#268bd2'
$green   = '#859900'
$orange  = '#cb4b16'
$red     = '#dc322f'
$yellow  = '#b58900'

def section(hash)
  hash['separator_block_width'] = $separator_width
  hash
end

def wifi_match
  /yes:(.*)\n/.match(%x{nmcli -t -c no -f active,ssid,signal dev wifi})
end

def wifi_connected?
  not wifi_match.nil?
end

def wifi
  ssid, percent = wifi_match[1].split(':')
  section({:full_text => " #{ssid} #{percent}%"})
end

class Battery
  attr_reader :available, :color, :icon

  def initialize(name)
    @name = name.upcase
    now  = File::open("/sys/class/power_supply/#{@name}/energy_now")  { |f| f.read.to_f }
    full = File::open("/sys/class/power_supply/#{@name}/energy_full") { |f| f.read.to_f }
    @available = now/full*100.0

    case
    when @available >= 87
      @icon = ''
      @color = $green
    when @available >= 62
      @icon = ''
      @color = $yellow
    when @available >= 37
      @icon = ''
      @color = $yellow
    when @available >= 12
      @icon = ''
      @color = $orange
    else
      @icon = ''
      @color = $red
    end
  end

  def to_s
    sprintf("#{@icon} #{@name[3,]} %.2f%%", @available)
  end
end

def battery(name)
  b = Battery.new(name)
  section({:full_text => b.to_s, :color => b.color})
end

def on_ac?
  File.open('/sys/class/power_supply/AC/online') do |f|
    f.read.to_i.nonzero?
  end
end

def charging
  section({:full_text => '', :color => $green})
end

def brightness
  b = %x{brightness get}
  section({:full_text => " #{b}%"})
end

def audio
  # Get the volume and mute information from pactl. This assumes that there is only one
  # sink and that the pactl output looks like the one in the below example. The volume is
  # presented as an average of the two volume channels.
  #
  # This should really be done using some sort of API.
  #
  # Example pactl output:
  # ...
  # Mute: yes
  # Volume: front-left: 42997 /  66% / -10.98 dB,   front-right: 42997 /  66% / -10.98 dB
  # ...
  out = %x{pactl list sinks}
  m = /Mute:\s*(.*)/.match(out)
  m = m[1] == 'yes' ? '(muted)' : ''
  v = %r{Volume:.+?/\s*(\d+%)\s*/.+?/\s*(\d+%)\s*/}.match(out)
  v = (v[1].chop.to_i+v[2].chop.to_i)/2
  section({'full_text': " #{v}%#{m}"})
end

def layout
  l = %x{xkblayout}
  section({:full_text => " #{l}", :color => $blue})
end

def date
  {:full_text => "#{Time.new.strftime('%a %b %d %H:%M')}"}
end

def empty
  {:full_text => ''}
end

puts '{"version": 1}'
puts '['
while true
  puts [
    wifi_connected? ? wifi : empty,
    battery('bat1'),
    battery('bat0'),
    on_ac? ? charging : empty,
    brightness,
    audio,
    layout,
    date
  ].to_json, ', '
  $stdout.flush
  sleep $interval
end

# vim: et sts=2 sw=2 ai:
