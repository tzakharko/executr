
# executr

<!-- badges: start -->
<!-- badges: end -->

Execute R tasks asynchronously on a worker pool

## Overview

The `executr` package implements a simple API for robust asynchronous execution 
of R code. It does not attempt to be a comprehensive solution for parallel 
programming (there are far better packages out there for this, such as `parallel`, 
`future`, `async` and others). Instead, this package is designed with a specific 
scenario in mind:

- Tasks are relatively long-running (at least dozens of seconds), and logically 
  independent from each other (no communication required)

- A failure or crash of one task should not affect other running tasks (robustness)

- Tasks can be scheduled on different queues with different priorities, limits and
  scheduling policies 

- Task creation and collection is performed by a single main "coordinator" thread

These are the main features of `executr`:

- A serializable closure type, `delayed_eval` (representing delayed computation) 
  which captures it's environment eagerly at the moment of creation

- A functional API, user-provided closures are invoked on the main thread 
  when a task was completed or has failed

- A polling executor model (the coordinator thread is required to repeatedly call
  `executor_step()` to synchronize the executor state)

- Multiple user-defined queues for submitting tasks that differ in priority and other
  policies 

- A simple executor that runs scheduled tasks in a separate `R` subprocess, up to
  a prescribed maximal number of tasks running in parallel (while honoring the 
  queue-specific limits)

`executr` uses `callr` to manage the parallel workers. Each task is executed in a 
fresh `R` session (it is assumed that the startup costs are negligible with the 
task running times).    


## Installation

You can install the development version of executr from 
[GitHub](https://github.com/tzakharko/executr):

``` r
# install.packages("devtools")
devtools::install_github("tzakharko/executr")
```

## Usage

Create and launch tasks:

``` r
library(executr)
library(magrittr)

for(i in 1:10)
  # construct the closure 
  # capture list is specified explicitly 
  delayed_eval({
    Sys.sleep(runif(1, 1, 10))
    i*2
  }, i=i) %>%
  # submit the closure as a task to the default queue
  # providing the function to call when the task is completed
  submit_task(default_executor_queue, function(value, i) {
    cat("Got ", value, " for i=", i, "\n", sep="")
  })
}

# run the executor 
# this will exit when no task is remaining
while(executor_has_pending_tasks()) executor_step()
```

Use multiple queues with different priorities:

```r
# for database fetch tasks
# maximally 4 workers (due to database server limitation)
# high priority
fetch_queue <- make_executor_queue(priority=1, max_workers=4)


submit_task(..., fetch_queue, ...)
submit_task(..., fetch_queue, ...)
submit_task(..., fetch_queue, ...)

...

submit_task(..., default_executor_queue, ...)
submit_task(..., default_executor_queue, ...)
submit_task(..., default_executor_queue, ...)


# run the executor 
# up to 4 fetch tasks will be scheduled simultaneously
# tasks from the default queue will be scheduled only if
# there is additional worker availability or after all
# fetch tasks are done
while(executor_has_pending_tasks()) executor_step()
```
