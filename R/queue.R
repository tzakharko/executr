NULL
#' @include state.R

schedule_task_in_queue <- function(queue, id) {
  order_policy <- queue$order_policy
  task_list    <- queue$scheduled_tasks

  # find the position where to insert the task
  # we use binary search
  high <- length(task_list)
  low  <- 0L
  while (low < high && high > 0L) {
    if (order_policy(task_list[[high]], id)) {
      break
    }

    mid <- low + (high - low) %/% 2

    if (mid > 0L && order_policy(task_list[[mid]], id)) {
      low <- mid
      high <- high - 1L
    } else {
      high <- mid
    }
  }

  queue$scheduled_tasks <- append(queue$scheduled_tasks, id, after=high)
}


#' @export
make_executor_queue <- function(
  max_workers = NULL, 
  priority = 0, 
  order_policy = `<`
) {
  if (is.null(max_workers)) max_workers <- Inf

  # build a queue object
  queue <- rlang::new_environment(
    list(
      running_tasks = integer(),
      scheduled_tasks = integer(),
      max_workers = max_workers,
      priority = priority,
      order_policy = order_policy
    )
  )
  queue <- structure(queue, class="executor-queue")

  # add the queue to the executor state
  executor_state$queues <- c(executor_state$queues, list(queue))

  # and make sure that the queues are sorted according 
  # to their priority
  priority <- sapply(executor_state$queues, function(q) q$priority)
  executor_state$queues <- executor_state$queues[order(-priority)]

  # and return this queue
  queue
} 

#' @export
`print.executor-queue` <- function(x, ...) {
  cat("<executor task queue>", format(x), "\n")
}


#' @export
default_executor_queue <- make_executor_queue()


