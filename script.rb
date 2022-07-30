require "tty/box"
require "tty/screen"
require "tty/spinner"

# p TTY::Screen.width

box = TTY::Box.frame(width: TTY::Screen.width, title: { top_center: " Setting up CI Runner " }, border: :thick, style: { border: { fg: :bright_yellow } }, padding: [0, 1]) do
  spinner = TTY::Spinner.new

  spinner.spin
end

puts box
