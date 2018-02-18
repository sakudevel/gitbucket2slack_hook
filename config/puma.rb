threads 2, 4


root = "#{Dir.getwd}"

pidfile "#{root}/tmp/puma/pid"
state_path "#{root}/tmp/puma/state"
rackup "#{root}/config.ru"

activate_control_app

