require "drb/drb"

URI="druby://localhost:8787"


class Hello
  def world
    "hello"
  end
end

DRb.start_service(URI, Hello.new)
system("chruby ruby-3.1.1")
system("ruby client.rb")
DRb.stop_service
