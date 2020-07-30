#' @export
submit_task <- function(expr, queue, collect, failure = stop, start = function() {}) {
  assert_that(inherits(expr, "delayed_eval"))
  assert_that(rlang::is_function(collect))
  assert_that(rlang::is_function(failure))
  assert_that(rlang::is_function(start))
  assert_that(inherits(queue, "executor-queue"))

  # generate a task ID
  id <- generate_task_id()

  # build the task object
  task <- rlang::new_environment(list(
    id = id,
    expr = expr, 
    queue = queue,
    collect = collect,
    failure = failure,
    start = start,
    status = "scheduled"
  ))

  # add it to the task list
  executor_state$task_list[[id]] <- task

  # add it to the queue
  schedule_task_in_queue(queue, id)

  # and return the task
  invisible(structure(id, class="executor-task"))
}


#' @export
executor_has_pending_tasks <- function() {
  length(executor_state$workers) > 0 || any(sapply(executor_state$queues, function(q) {
    length(q$scheduled_tasks) > 0
  }))
}


#' @export
executor_active_worker_count <- function() {
  length(executor_state$workers)
}


call_task_hook <- function(hook, values, task) {
  available_args <- c(task$expr$capture_list, list(.taskid = task$id))
  
  # build the argument list from one's requested by the hook
  args <- c(values, available_args[names(formals(hook))[-1]])

  do.call(hook, args)
}


#' @export
executor_step <- function(timeout = 0.25) {
  # schedule new tasks
  start_tasks()

  # wait for workers to fire an event
  processx::poll(executor_state$workers, timeout*100)

  # walk all the running tasks, checking for events
  i <- 1L
  while (i <= length(executor_state$workers)) {
    worker <- executor_state$workers[[i]]
    i <- i + 1L

    # fetch the event, move to next worker if there is no event
    event <- worker$read()
    if (is.null(event)) next

    if (event$code == 200 && is.null(event$error)) {
      task <- attr(worker, "task")
      call_task_hook(task$collect, list(event$result), task)
    } else 
    if (event$code == 200) {
      task <- attr(worker, "task")
      call_task_hook(task$failure, list(event$error$parent$error), task)
    } else
    if (event$code %in% c(501, 502)) {
      task <- attr(worker, "task")
      error <- rlang::error_cnd("executor-error", message="The worker subprocess has crashed")
      call_task_hook(task$failure, list(error), task)
    } else {
      next
    }

    # stop the worker and remove it from the list
    worker$close()
    i <- i - 1L
    executor_state$workers <- executor_state$workers[-i]

    # update the task and remove it from it's queue
    task$status <- "done"
    task$queue$running_tasks <- setdiff(task$queue$running_tasks, task$id)
  }

  # schedule new tasks
  start_tasks()
} 


