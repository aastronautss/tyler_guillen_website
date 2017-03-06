app_path = File.expand_path(File.dirname(__FILE__))

# Set the working application directory
# working_directory "/path/to/your/app"
working_directory app_path

# Unicorn PID file location
# pid "/path/to/pids/unicorn.pid"
pid app_path + '/tmp/unicorn.pid'

# Path to logs
# stderr_path "/path/to/logs/unicorn.log"
# stdout_path "/path/to/logs/unicorn.log"
stderr_path app_path + '/log/unicorn.log'
stdout_path app_path + '/log/unicorn.log'

# Unicorn socket
# listen "/tmp/unicorn.[app name].sock"
listen app_path + '/tmp/unicorn.sock', backlog: 64

# Number of processes
# worker_processes 4
worker_processes 4

# Time-out
timeout 300
