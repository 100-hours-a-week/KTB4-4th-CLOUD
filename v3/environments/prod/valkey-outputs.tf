output "valkey_stream_primary_endpoint" {
  description = "V3 Production Streams primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "valkey_stream_security_group_id" {
  value = module.valkey.security_group_id
}

