require 'drb/drb'

# The URI to connect to
SERVER_URI="druby://localhost:8787"
DRb.start_service

bla = DRbObject.new_with_uri(SERVER_URI)
p RUBY_VERSION
