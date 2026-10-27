# frozen_string_literal: true

# Puma, as Cistergraphia is served (docs/serving.md). Puma reads this file
# when started with `puma` or `rackup`.
#
# Reading or inscribing a plate is CPU work in Ruby: the threads of one
# process share a core (the GVL), and worker processes do not.
# - WEB_CONCURRENCY: worker processes, about one per core (default 0: a
#   single process, as in development)
# - PUMA_THREADS: threads per process (default 3): enough to keep serving
#   pages while a large plate is read, few enough that a burst of heavy reads
#   waits in the queue instead of slowing every page down at once

workers = Integer(ENV.fetch('WEB_CONCURRENCY', 0))
threads_count = Integer(ENV.fetch('PUMA_THREADS', 3))

workers workers
threads threads_count, threads_count
preload_app! if workers.positive?
port Integer(ENV.fetch('PORT', 9292)) # a platform's PORT; -b or rackup -p take precedence
