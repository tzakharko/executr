get_max_workers <- function() {
  # get the max_workers option
  workers <- getOption("executor.max_workers")
  if (!is.null(workers)) return(workers)

  # otherwise try the automatic detection
  workers <- parallel::detectCores()
  if (is.null(workers)) 4L else workers
}


# Find the queue that has a task that can be started
get_next_queue_index <- function() {
  for (i in seq_along(executor_state$queues)) {
    queue <- executor_state$queues[[i]]

    # skip this queue if there are no tasks to schedule
    if (length(queue$scheduled_tasks) == 0) next
    if (length(queue$running_tasks) >= queue$max_workers) next

    # this is the queue we want
    return(i)
  }

  0L
}

# Starts the tasks using the available worker capacity
#
# This function will start tasks from queues using round-robin
# scheduling. The queues with higher priority will be always
# processed first. A lower-priority task might get started
# if the higher-priority queues at at their local worker
# capacity
start_tasks <- function() {
  # start new tasks until max number of workers is reached
  while (length(executor_state$workers) < get_max_workers()) {
    # find the next queue that has tasks to be scheduled
    q_index <- get_next_queue_index()

    # quit if there is nothing to schedule
    if (q_index == 0L) return()

    queue <- executor_state$queues[[q_index]]

    # pop the next task from the queue
    task <- get_task_by_id(queue$scheduled_tasks[[1]])
    assert_that(!is.null(task), msg="Internal error: unknown task")
    queue$scheduled_tasks <- queue$scheduled_tasks[-1]
    
    # start a worker
    worker <- callr::r_session$new()
    worker$call(as.function(task$expr))
    attr(worker, "task") <- task 

    # update the bookeeping
    task$status <- "running"
    queue$running_tasks <- c(queue$running_tasks, task$id)
    executor_state$workers <- c(executor_state$workers, list(worker))

    call_task_hook(task$start, list(), task)

    # push this queue to the end and sort the queues by priority
    # this will ensure that queues are processed in a round-robin
    # fashion while honouring priority
    executor_state$queues <- c(executor_state$queues[-q_index], list(queue))
    priority <- sapply(executor_state$queues, function(q) q$priority)
    executor_state$queues <- executor_state$queues[order(-priority)]
  }
}

