# Understanding Concepts

This page provides some reference explanations for the concepts used

## Availability in depth
We measure the availability of the stack using prometheus and blackbox exporter.

The exporter calls an endpoint defined in the yaml at a given frequency, and exposes the result as either a 0 or 1. 

The success metric is 0 or 1, so our uptime over a time period is the average of the value over that period. EG - `avg_over_time(probe_success[8h]) * 100 `

Probing frequency is defined by the prometheus scrape_interval in the prometheus config, the exporter itself doesnt know. Example interval by default is every 10s 


### Availability at a given point in time
What does the percentage availability mean? Lets explain with an example:

Say we see in our 8h availability graph, we have 98.77% availability at 15:00 yesterday.

Our probe interval is every 10 seconds. This means that in 8 hours we make 2440 calls.

For 98.77% availability, we must have had 30 calls fail over the time period (2440 * 0.9877)

30 failing calls over the time period could happen in a few ways:

- We could have just dropped 30 calls spaced evenly over the period of 8 hours, which probably can't be noticed
-  we could have had a outage of 0% availability for 5 minutes in sequence, where the thing is properly broken for that period. This would mean 30 calls failed, so uptime over 8 hours is 98.7% 

This show why we want to understand availability over different time windows
