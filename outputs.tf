output "ecs_cluster_arn" {
  value = aws_ecs_cluster.prefect.arn
}

output "prefect_worker_service_name" {
  value = aws_ecs_service.prefect_worker.name
}
