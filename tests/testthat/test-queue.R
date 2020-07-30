test_that("Multiple queues are scheduled in a round-robin order", {
  # set the max number of workers to one to ensure that they
  # are scheduled sequentially
  options(executor.max_workers = 1L)

  # queue creation
  q0 <- make_executor_queue()
  q1 <- make_executor_queue()


  # this is where the order of completion will be recorded
  completion_order <- integer()

  # simple tasks that records the order of task completion
  task <- delayed_eval(0)
  collect <- function(value, .taskid) {
    completion_order <<- c(completion_order, .taskid)    
  }

  task_ids <- c(
    submit_task(task, q0, collect),
    submit_task(task, q0, collect),
    submit_task(task, q1, collect),
    submit_task(task, q1, collect)
  )

  # execute all tasks
  while(executor_has_pending_tasks()) executor_step()

  # we expect the tasks from queues to be interleaved
  expect_equal(completion_order, task_ids[c(1, 3, 2, 4)])
})


test_that("Higher priority tasks are scheduled before the lower priority ones", {
  # set the max number of workers to one to ensure that they
  # are scheduled sequentially
  options(executor.max_workers = 1L)

  # queue creation
  q0 <- make_executor_queue()
  q1 <- make_executor_queue(priority=1)

  # this is where the order of completion will be recorded
  completion_order <- integer()

  # simple tasks that records the order of task completion
  task <- delayed_eval(0)
  collect <- function(value, .taskid) {
    completion_order <<- c(completion_order, .taskid)    
  }

  task_ids <- c(
    submit_task(task, q0, collect),
    submit_task(task, q0, collect),
    submit_task(task, q1, collect),
    submit_task(task, q1, collect)
  )

  # execute all tasks
  while(executor_has_pending_tasks()) executor_step()

  # we expect the tasks from q1 to be submitted first
  expect_equal(completion_order, task_ids[c(3, 4, 1, 2)])

  options(executor.max_workers = NULL)
})


test_that("Queue worker limit is honoured", {
  # set the max number of workers to ensure that 
  # more than 3 tasks can be run in parallel
  options(executor.max_workers = 8L)

  q0 <- make_executor_queue(max_workers=2L)
  q1 <- make_executor_queue(max_workers=1L)
  
  # simple tasks that do nothing
  task <- delayed_eval(0)
  collect <- function(value) {}

  # number of tasks to spawn
  N <- 4
  for(i in 1:N) submit_task(task, q0, collect)
  for(i in 1:N) submit_task(task, q1, collect)

  n_active_workers <- 0L

  # execute all tasks while recording the 
  # number of active workers
  while(executor_has_pending_tasks()) {
    executor_step()
    
    n_active_workers <- max(
      executor_active_worker_count(), 
      n_active_workers
    )
  }

  # active worker count cannot exceed 3 at any time
  expect_true(n_active_workers <= 3L)
})


test_that("Queue order policy works correctly", {
  # set the max number of workers to one to ensure that they
  # are scheduled sequentially
  options(executor.max_workers = 1L)

  # set up the policy that schedules tasks with 
  # even task id before the tasks with odd task id
  q0 <- make_executor_queue(order_policy = function(a, b) {
    (((a %% 2) == (b %% 2)) && (a < b)) || (a %% 2 == 0)
  })

  # this is where the order of completion will be recorded
  completion_order <- integer()

  # simple tasks that records the order of task completion
  task <- delayed_eval(0)
  collect <- function(value, .taskid) {
    completion_order <<- c(completion_order, .taskid)    
  }

  # number of tasks to spawn
  N <- 8
  task_ids <- replicate(N, submit_task(task, q0, collect))

  # execute all tasks
  while(executor_has_pending_tasks()) executor_step()

  # we expect the tasks to be completed in the order
  # specified by the policy
  expect_equal(completion_order, task_ids[c(2, 4, 6, 8, 1, 3, 5, 7)])
})


